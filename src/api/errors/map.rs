use std::io::ErrorKind;

use super::ErrorId;

/// Map errors from atomic swap/symlink replacement to stable `ErrorId`.
#[must_use]
pub fn map_swap_error(e: &std::io::Error) -> ErrorId {
    let emsg = e.to_string();
    if emsg.contains("sidecar write failed") {
        return ErrorId::E_POLICY;
    }
    match e.raw_os_error() {
        Some(code) if code == libc::EXDEV => ErrorId::E_EXDEV,
        _ => ErrorId::E_ATOMIC_SWAP,
    }
}

/// Map restore error kinds to stable `ErrorId` for telemetry.
///
/// Keep this conservative to support older stable compilers; many `ErrorKind`
/// variants (e.g., `NotADirectory`, `IsADirectory`) were stabilized later.
#[must_use]
pub fn map_restore_error_kind(kind: ErrorKind) -> ErrorId {
    match kind {
        ErrorKind::NotFound => ErrorId::E_BACKUP_MISSING,
        _ => ErrorId::E_RESTORE_FAILED,
    }
}
