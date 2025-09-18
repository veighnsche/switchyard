#!/usr/bin/env bash
set -euo pipefail
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SELF_DIR}/_common.sh"

cd "${REPO_ROOT}"

log "Building docs with docs.rs cfg"
export RUSTDOCFLAGS="--cfg docsrs"
cargo doc --no-deps
