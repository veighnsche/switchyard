#!/usr/bin/env bash
set -euo pipefail
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SELF_DIR}/_common.sh"

ensure_python
cd "${REPO_ROOT}"

log "Running BDD (failure-only output on failure)"
python3 scripts/bdd_filter_results.py --fail-only

# Upload BDD lastrun log (if present)
upload_artifact "bdd-lastrun" "target/bdd-lastrun.log"
