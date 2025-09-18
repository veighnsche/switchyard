#!/usr/bin/env bash
set -euo pipefail

# Resolve roots
_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Crate root = two directories up (scripts/ci/ -> crate/)
CRATE_ROOT="$(cd "${_SELF_DIR}/../.." && pwd)"
# Workspace root (git toplevel if available), fallback to crate root
if git -C "${_SELF_DIR}" rev-parse --show-toplevel >/dev/null 2>&1; then
  WORKSPACE_ROOT="$(git -C "${_SELF_DIR}" rev-parse --show-toplevel)"
else
  WORKSPACE_ROOT="${CRATE_ROOT}"
fi
# Default to crate root for cargo-related operations
REPO_ROOT="${CRATE_ROOT}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-${REPO_ROOT}/artifacts}"

log() { printf "[%s] %s\n" "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*" >&2; }
die() { printf "ERROR: %s\n" "$*" >&2; exit 1; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }

mkdir -p "${ARTIFACTS_DIR}"

ensure_rustup() { require_cmd rustup; }
ensure_cargo() { require_cmd cargo; }

ensure_toolchain() {
  local tc="${1:-}"
  [[ -z "${tc}" ]] && return 0
  ensure_rustup
  if ! rustup toolchain list | awk '{print $1}' | grep -qx "${tc}"; then
    log "Installing Rust toolchain ${tc}"
    rustup toolchain install "${tc}" --profile minimal
  fi
}

with_toolchain() {
  local tc="${1:-}"
  shift || true
  if [[ -n "${tc}" ]]; then
    ensure_toolchain "${tc}"
    rustup run "${tc}" "$@"
  else
    "$@"
  fi
}

ensure_components() {
  local comps=("$@")
  for c in "${comps[@]}"; do
    rustup component add "$c" >/dev/null 2>&1 || true
  done
}

ensure_mdbook() {
  ensure_cargo
  if ! command -v mdbook >/dev/null 2>&1; then
    log "Installing mdbook"
    cargo install mdbook
  fi
}

ensure_mdbook_linkcheck() {
  ensure_cargo
  if ! command -v mdbook-linkcheck >/dev/null 2>&1; then
    log "Installing mdbook-linkcheck"
    cargo install mdbook-linkcheck
  fi
}

ensure_python() {
  require_cmd python3
}

upload_artifact() {
  local name="$1"
  local path="$2"
  local dest="${ARTIFACTS_DIR}/${name}"
  mkdir -p "${dest}"
  if compgen -G "${REPO_ROOT}/${path}" >/dev/null; then
    # If path is a directory, copy its contents; else copy the file(s)
    if [[ -d "${REPO_ROOT}/${path}" ]]; then
      cp -a "${REPO_ROOT}/${path}/." "${dest}/"
    else
      # May be a glob
      cp -a ${REPO_ROOT}/${path} "${dest}/" 2>/dev/null || true
    fi
    log "Artifact '${name}' staged under ${dest}"
  else
    log "No files to upload for '${name}' at path '${path}'"
  fi
}

git_sha() {
  git -C "${REPO_ROOT}" rev-parse HEAD 2>/dev/null || echo "local"
}
