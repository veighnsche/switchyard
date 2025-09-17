#!/usr/bin/env python3
"""
Verify that all artifacts listed in .provenance/manifest.json match their sha256 digests.
Exits non-zero on mismatch.
"""
from __future__ import annotations
import hashlib
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
MANIFEST = REPO_ROOT / ".provenance" / "manifest.json"

def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()

def main() -> int:
    if not MANIFEST.exists():
        print(f"Missing manifest: {MANIFEST}", file=sys.stderr)
        return 2
    m = json.loads(MANIFEST.read_text(encoding="utf-8"))
    arts = m.get("artifacts", [])
    ok = 0
    for a in arts:
        p = a.get("path")
        want = a.get("sha256")
        if not p or not want:
            print(f"Invalid artifact entry: {a}", file=sys.stderr)
            return 2
        ap = REPO_ROOT / p
        if not ap.exists():
            print(f"Missing artifact file: {ap}", file=sys.stderr)
            return 3
        got = sha256_file(ap)
        if got != want:
            print(f"Digest mismatch for {p}: want={want} got={got}", file=sys.stderr)
            return 4
        ok += 1
    print(f"Verified {ok}/{len(arts)} artifact digests")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
