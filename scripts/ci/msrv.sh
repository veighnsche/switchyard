#!/usr/bin/env bash
set -euo pipefail
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SELF_DIR}/_common.sh"

MSRV_TOOLCHAIN="${MSRV_TOOLCHAIN:-1.81.0}"

cd "${REPO_ROOT}"

log "Ensuring Rust toolchain ${MSRV_TOOLCHAIN}"
ensure_toolchain "${MSRV_TOOLCHAIN}"

log "Building workspace (all features) with ${MSRV_TOOLCHAIN}"
with_toolchain "${MSRV_TOOLCHAIN}" cargo build --all-features --workspace
