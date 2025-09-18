#!/usr/bin/env bash
set -euo pipefail
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SELF_DIR}/_common.sh"

MSRV_TOOLCHAIN="${MSRV_TOOLCHAIN:-1.89.0}"

cd "${REPO_ROOT}"

log "Ensuring Rust toolchain ${MSRV_TOOLCHAIN}"
ensure_toolchain "${MSRV_TOOLCHAIN}"

log "Building crate (all features) with ${MSRV_TOOLCHAIN}"
# Build only this crate to mirror the upstream switchyard repo CI. Building the full
# workspace here may pull in unrelated crates from the monorepo and fail MSRV unnecessarily.
with_toolchain "${MSRV_TOOLCHAIN}" cargo build --all-features
