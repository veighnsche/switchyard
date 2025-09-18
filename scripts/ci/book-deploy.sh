#!/usr/bin/env bash
set -euo pipefail
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SELF_DIR}/_common.sh"

cd "${REPO_ROOT}"

# Build first
"${SELF_DIR}/book-build.sh"

# Local 'deploy' is just staging the built site into artifacts
log "Staging book for 'deploy' (no push)"
upload_artifact "mdbook-site" "book/book"
