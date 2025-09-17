#!/usr/bin/env python3
"""
Verify Ed25519 signature for .provenance/manifest.json using the
PROVENANCE_ED25519_PUBLIC_KEY_B64 environment variable.
Exits non-zero if verification fails or public key is present but signature missing.
"""
from __future__ import annotations
import base64
import os
import sys
from pathlib import Path

try:
    from nacl.signing import VerifyKey
except Exception as e:
    print("PyNaCl not available: install with 'pip install pynacl'", file=sys.stderr)
    sys.exit(2)

REPO_ROOT = Path(__file__).resolve().parents[3]
MAN = REPO_ROOT / ".provenance" / "manifest.json"
SIG = REPO_ROOT / ".provenance" / "manifest.json.sig"


def main() -> int:
    pk_b64 = os.environ.get("PROVENANCE_ED25519_PUBLIC_KEY_B64", "")
    if not pk_b64:
        print("No public key provided; skipping signature verification.")
        return 0
    if not MAN.exists():
        print(f"Missing manifest: {MAN}", file=sys.stderr)
        return 2
    if not SIG.exists():
        print("Public key provided but signature file is missing:", SIG, file=sys.stderr)
        return 3
    data = MAN.read_bytes()
    sig = base64.b64decode(SIG.read_text(encoding="utf-8").strip())
    vk = VerifyKey(base64.b64decode(pk_b64))
    try:
        vk.verify(data, sig)
        print("Signature OK")
        return 0
    except Exception as e:
        print(f"Signature verification failed: {e}", file=sys.stderr)
        return 4


if __name__ == "__main__":
    raise SystemExit(main())
