#!/usr/bin/env bash
set -euo pipefail
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SELF_DIR}/_common.sh"

cd "${REPO_ROOT}"

ensure_python
ensure_cargo

log "Installing Python dependency: pynacl (for Ed25519)"
python3 -m pip install --upgrade pip >/dev/null 2>&1 || true
python3 -m pip install pynacl >/dev/null 2>&1 || true

log "Generate artifacts (tests, coverage, manifest)"
# Uses PROVENANCE_ED25519_PRIVATE_KEY_B64 if provided in environment
python3 scripts/provenance_ci.py

log "Verify digests"
python3 scripts/verify_provenance_digests.py

log "Verify signature (if public key provided)"
# Uses PROVENANCE_ED25519_PUBLIC_KEY_B64 from environment if set
python3 scripts/verify_provenance_signature.py

# Upload artifacts
upload_artifact "provenance-ci-$(git_sha)" "ci/"
upload_artifact "provenance-index-$(git_sha)" ".provenance/manifest.json*"
