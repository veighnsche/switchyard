#!/usr/bin/env bash
set -euo pipefail
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SELF_DIR}/_common.sh"

cd "${REPO_ROOT}"

ensure_mdbook
ensure_mdbook_linkcheck

log "Building mdBook"
mdbook build book

upload_artifact "mdbook-site" "book/book"
