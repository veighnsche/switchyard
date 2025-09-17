# Provenance Integration (Artifact-First)

This repository integrates an artifact-first flow to power a Provenance host service. The CI generates test/coverage artifacts, a Proofdown front page, and a signed manifest that enumerates and digests all artifacts. Outputs are commit-pinned and safe for static hosting.

## Outputs (repository layout)

- `ci/front_page.pml` — Proofdown front page, references artifacts by id.
- `ci/tests/summary.json` — Test totals: `{ "total": N, "passed": M, "failed": K, "duration_seconds": 12.3 }`.
- `ci/coverage/coverage.json` — Coverage totals/files: `{ "total": {"pct": 85.2}, "files": [{"path": "src/...", "pct": 92.1}] }`.
- `ci/tests/failures.md` — Optional failure details (always present; "No failures detected." when green).
- `.provenance/manifest.json` — Canonical JSON manifest: version, repo, commit, workflow_run, front_page, artifacts[] entries with sha256.
- `.provenance/manifest.json.sig` — Base64 Ed25519 signature over canonical bytes (present when signing key is configured).

All artifact references in Proofdown use ids, not paths: `tests-summary`, `coverage`, `failures`.

## CI jobs

- `switchyard-provenance` (runs after `test-unit`)
  - Installs Python + PyNaCl (Ed25519), runs `cargo/switchyard/scripts/provenance_ci.py` to generate artifacts, coverage, manifest, optional signature.
  - Verifies SHA-256 digests listed in the manifest against the files on disk.
  - If `PROVENANCE_ED25519_PUBLIC_KEY_B64` is set, verifies that `.sig` is present and validates over canonical manifest bytes.
  - Uploads `ci/` and `.provenance/{manifest.json,manifest.json.sig}` as GitHub Actions artifacts named with the commit SHA.

- `provenance-publish` (main branch only)
  - Downloads the artifacts and publishes them to GitHub Pages under `provenance/<commit-sha>/` so the host service can consume a commit-pinned index.
  - Published paths include:
    - `https://<org>.github.io/<repo>/provenance/<sha>/.provenance/manifest.json`
    - `https://<org>.github.io/<repo>/provenance/<sha>/ci/front_page.pml`

## Running locally (optional)

To generate artifacts locally (writes into your working tree):

```
python3 cargo/switchyard/scripts/provenance_ci.py
```

This will run `cargo test -p switchyard-fs`, attempt to run coverage with `cargo tarpaulin` (if available), and write the manifest. If `PROVENANCE_ED25519_PRIVATE_KEY_B64` is set in your environment, a signature will be produced.

## Secrets

- `PROVENANCE_ED25519_PRIVATE_KEY_B64` — Base64-encoded 32-byte Ed25519 private key (sk). When provided, CI signs `.provenance/manifest.json` and produces `.provenance/manifest.json.sig`.
- `PROVENANCE_ED25519_PUBLIC_KEY_B64` — Base64-encoded 32-byte Ed25519 public key (pk). When provided, CI verifies the signature and fails if missing/invalid.

### Generate keys

Using Python (PyNaCl):

```python
from nacl.signing import SigningKey
import base64
sk = SigningKey.generate()
print('PROVENANCE_ED25519_PRIVATE_KEY_B64=', base64.b64encode(bytes(sk)).decode())
print('PROVENANCE_ED25519_PUBLIC_KEY_B64=', base64.b64encode(bytes(sk.verify_key)).decode())
```

Using OpenSSL (1.1.1+):

```bash
# Private key (PEM)
openssl genpkey -algorithm ED25519 -out sk.pem
# Extract raw 32-byte private key and base64-encode
python - <<'PY'
import base64
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.backends import default_backend
from pathlib import Path
key = serialization.load_pem_private_key(Path('sk.pem').read_bytes(), password=None, backend=default_backend())
raw = key.private_bytes(encoding=serialization.Encoding.Raw, format=serialization.PrivateFormat.Raw, encryption_algorithm=serialization.NoEncryption())
print(base64.b64encode(raw).decode())
PY
# Public key (base64 raw)
openssl pkey -in sk.pem -pubout -outform DER | tail -c 32 | base64
```

## Determinism & safety

- Outputs are canonicalized with sorted keys, compact JSON, UTF-8, trailing newline.
- Coverage file list is sorted by repo-relative path; percentages rounded to 1 decimal.
- No timestamps or random identifiers are written.
- The Proofdown page uses only whitelisted components (`grid`, `card`, `artifact.*`).
- CI fails on digest mismatch. If a public key is configured, CI also fails on missing/invalid signatures.

## Host service

Point your viewer/worker at the published, commit-pinned manifest URL. It must validate the signature and the SHA-256 digests, then render `ci/front_page.pml` with artifact ids only. Unknown components/attributes must be rejected by the renderer.
