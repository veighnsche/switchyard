#!/usr/bin/env bash
set -euo pipefail
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SELF_DIR}/_common.sh"

cd "${REPO_ROOT}"

# Configure toolchains
# If TOOLCHAIN is set, use that single toolchain. Otherwise, use TOOLCHAINS (space-separated) or default to stable beta nightly
if [[ -n "${TOOLCHAIN:-}" ]]; then
  TOOLCHAINS_LIST=("${TOOLCHAIN}")
else
  read -r -a TOOLCHAINS_LIST <<< "${TOOLCHAINS:-stable beta nightly}"
fi

for tc in "${TOOLCHAINS_LIST[@]}"; do
  log "Setting up Rust toolchain: ${tc}"
  ensure_toolchain "${tc}"

  log "Build (all features) on ${tc}"
  with_toolchain "${tc}" cargo build --all-features

  log "Test (all features, nocapture) on ${tc}"
  # Avoid passing --nocapture since some integration tests may disable the test harness (e.g., cucumber),
  # which would interpret --nocapture as a binary arg and fail. This mirrors CI behavior closely enough.
  with_toolchain "${tc}" cargo test --all-features

done
