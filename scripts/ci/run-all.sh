#!/usr/bin/env bash
set -euo pipefail
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SELF_DIR}/_common.sh"

cd "${REPO_ROOT}"

SCRIPTS=(
  "${SELF_DIR}/lint.sh"
  "${SELF_DIR}/test.sh"
  "${SELF_DIR}/msrv.sh"
  "${SELF_DIR}/docs.sh"
  "${SELF_DIR}/bdd.sh"
  "${SELF_DIR}/golden.sh"
  "${SELF_DIR}/spec-traceability.sh"
  "${SELF_DIR}/provenance.sh"
  "${SELF_DIR}/book-build.sh"
  "${SELF_DIR}/publish-dry-run.sh"
  # Optional/local-only: these simulate publish/deploy staging locally
  "${SELF_DIR}/provenance-publish.sh"
  "${SELF_DIR}/book-deploy.sh"
)

log "Running CI-equivalent scripts sequentially"

FAIL=0
for s in "${SCRIPTS[@]}"; do
  if [[ ! -x "$s" ]]; then
    log "Skipping non-executable script: $s"
    continue
  fi
  name="$(basename "$s")"
  if [[ ",${SKIP:-}," == *",${name},"* ]]; then
    log "Skipping ${name} due to SKIP env var"
    continue
  fi
  log "=== BEGIN ${name} ==="
  if ! "$s"; then
    log "=== FAIL ${name} ==="
    FAIL=1
  else
    log "=== PASS ${name} ==="
  fi
  echo
  echo

done

if [[ $FAIL -ne 0 ]]; then
  die "One or more steps failed"
fi

log "All steps completed successfully"
