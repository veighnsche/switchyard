#!/usr/bin/env bash
set -euo pipefail
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SELF_DIR}/_common.sh"

cd "${REPO_ROOT}"

ensure_cargo

log "Cargo package --list"
cargo package --list

log "Cargo publish --dry-run"
cargo publish --dry-run
