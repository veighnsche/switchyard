#!/usr/bin/env bash
set -euo pipefail
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SELF_DIR}/_common.sh"

ensure_python
cd "${REPO_ROOT}"

# Locate test_ci_runner.py; allow override via CI_RUNNER env var
CANDIDATES=(
  "${CI_RUNNER:-}"
  "${REPO_ROOT}/test_ci_runner.py"
  "${WORKSPACE_ROOT}/test_ci_runner.py"
  "${REPO_ROOT}/../test_ci_runner.py"
  "${REPO_ROOT}/../../test_ci_runner.py"
)
CI_RUNNER_PATH=""
for c in "${CANDIDATES[@]}"; do
  if [[ -n "${c}" && -f "${c}" ]]; then
    CI_RUNNER_PATH="${c}"
    break
  fi
done

if [[ -z "${CI_RUNNER_PATH}" ]]; then
  die "Could not find test_ci_runner.py. Set CI_RUNNER=/path/to/test_ci_runner.py or place it at repo root."
fi

log "Running golden diff (all scenarios)"
python3 "${CI_RUNNER_PATH}" --golden all --nocapture

upload_artifact "golden-diff" "golden-diff"
