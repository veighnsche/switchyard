#!/usr/bin/env bash
set -euo pipefail
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SELF_DIR}/_common.sh"

cd "${REPO_ROOT}"

SHA="$(git_sha)"
SITE_DIR="${REPO_ROOT}/_site"
DEST="${SITE_DIR}/provenance/${SHA}"

log "Preparing commit-pinned payload under ${DEST}"
mkdir -p "${DEST}/.provenance"

# Prefer artifacts from prior step, else fallback to working tree
CI_SRC="${ARTIFACTS_DIR}/provenance-ci-${SHA}"
INDEX_SRC="${ARTIFACTS_DIR}/provenance-index-${SHA}"
if [[ ! -d "${CI_SRC}" ]]; then CI_SRC="${REPO_ROOT}/ci"; fi
if [[ ! -d "${INDEX_SRC}" ]]; then INDEX_SRC="${REPO_ROOT}/.provenance"; fi

# Copy CI payload
if [[ -d "${CI_SRC}" ]]; then
  cp -a "${CI_SRC}/." "${DEST}/"
else
  log "WARN: CI source not found at ${CI_SRC}"
fi

# Copy provenance index
if [[ -d "${INDEX_SRC}" ]]; then
  cp -a "${INDEX_SRC}/." "${DEST}/.provenance/"
else
  log "WARN: Index source not found at ${INDEX_SRC}"
fi

# Check for front_page.pml (non-fatal)
if [[ ! -f "${REPO_ROOT}/ci/front_page.pml" ]]; then
  log "NOTE: ci/front_page.pml not found; continuing"
fi

# Minimal index.html as breadcrumb
cat >"${DEST}/index.html" <<EOF
<html><body>Commit-pinned artifacts published under provenance/${SHA}/</body></html>
EOF

# Stage as artifact for easy inspection
upload_artifact "provenance-site-${SHA}" "_site"
