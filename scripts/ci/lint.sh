#!/usr/bin/env bash
set -euo pipefail
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SELF_DIR}/_common.sh"

cd "${REPO_ROOT}"

log "Setting up Rust components: rustfmt, clippy"
ensure_rustup
ensure_cargo
ensure_components rustfmt clippy

log "Format check"
cargo fmt -- --check

log "Clippy (warnings as errors)"
cargo clippy --lib --bins -- -D warnings

log "Guardrails (switchyard crate)"
set -euo pipefail

# 1) No #[path] under src/api/
echo "Checking no #[path] under src/api/"
if grep -R --line-number "#[path]" src/api; then
  echo "ERROR: #[path] found under src/api" >&2
  exit 1
fi

# 2) No deprecated adapters::lock_file shim
echo "Checking no deprecated adapters::lock_file shim"
if grep -R --line-number "adapters::lock_file::" src tests; then
  echo "ERROR: adapters::lock_file:: usage found" >&2
  exit 1
fi

# 3) No legacy audit::emit_* calls outside src/logging/
echo "Checking no legacy audit::emit_* calls outside src/logging/"
if grep -R --line-number "audit::emit_" src | grep -v "^src/logging/"; then
  echo "ERROR: legacy audit::emit_* used outside src/logging/" >&2
  exit 1
fi

# 4) No direct FactsEmitter::emit outside src/logging/
echo "Checking no direct FactsEmitter::emit outside src/logging/"
if grep -R --line-number "FactsEmitter::emit" src | grep -v "^src/logging/"; then
  echo "ERROR: direct FactsEmitter::emit used outside src/logging/" >&2
  exit 1
fi

# 5) No public re-exports of low-level fs atoms
echo "Checking no public re-exports of low-level fs atoms"
if grep -R --line-number -E "^[[:space:]]*pub[[:space:]]+use[[:space:]]+atomic::" src/fs/mod.rs; then
  echo "ERROR: public fs atoms re-exported at src/fs/mod.rs" >&2
  exit 1
fi

# 6) Top-level rescue alias not used by consumers
echo "Checking top-level rescue alias not used by consumers"
if grep -R --line-number -E "\\buse[[:space:]]+switchyard::rescue\\b" src tests; then
  echo "ERROR: 'use switchyard::rescue' found; import from switchyard::policy::rescue instead" >&2
  exit 1
fi

echo "Switchyard guardrails passed"

log "Hermetic tests guard (no absolute system paths)"
if grep -R --line-number -E '"/(bin|sbin|usr|etc|var|proc|sys|dev|run|tmp)(/|"|$)' tests; then
  echo "ERROR: Absolute system path literal found in tests" >&2
  exit 1
fi

log "Zero-SKIP gate (no #[ignore] tests)"
if grep -R --line-number -E '^[[:space:]]*#\[ignore\]' tests; then
  echo "ERROR: #[ignore] present in tests; Zero-SKIP gate requires no skipped tests." >&2
  exit 1
fi

log "Changelog updated for switchyard crate changes"
if git rev-parse HEAD^ >/dev/null 2>&1; then
  changed=$(git diff --name-only HEAD^)
  if echo "$changed" | grep -E '^(src/|Cargo.toml|SPEC/|DOCS/|book/)'; then
    if ! echo "$changed" | grep -q '^CHANGELOG.md$'; then
      echo "ERROR: Detected changes without updating CHANGELOG.md" >&2
      echo "Changed files:" >&2
      echo "$changed" >&2
      exit 1
    fi
  fi
fi

log "Lint workflow completed successfully"
