#!/usr/bin/env bash
set -euo pipefail
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SELF_DIR}/_common.sh"

ensure_python
cd "${REPO_ROOT}"

log "Installing Python dependencies for traceability (pyyaml)"
python3 -m pip install --upgrade pip >/dev/null 2>&1 || true
python3 -m pip install pyyaml >/dev/null 2>&1 || true

log "Running SPEC traceability (non-blocking)"
(
  cd SPEC
  python3 tools/traceability.py || true
)

upload_artifact "spec-traceability-report" "SPEC/traceability.md"
