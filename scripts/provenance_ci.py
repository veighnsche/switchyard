#!/usr/bin/env python3
"""
Generate Provenance artifacts for the switchyard crate:
- ci/tests/summary.json (test totals)
- ci/coverage/coverage.json (per-file and total coverage)
- ci/tests/failures.md (optional; filled with details if failures occur)
- .provenance/manifest.json (canonicalized)
- .provenance/manifest.json.sig (Ed25519 signature; base64) if PROVENANCE_ED25519_PRIVATE_KEY_B64 is set

This script is CI-friendly and deterministic:
- No timestamps in outputs (duration is computed but rounded to 1 decimal in seconds)
- Sorted keys and stable list ordering

Environment variables consumed:
- GITHUB_REPOSITORY (owner/repo)
- GITHUB_SHA (full commit sha)
- GITHUB_RUN_ID
- GITHUB_RUN_ATTEMPT
- GITHUB_SERVER_URL
- PROVENANCE_ED25519_PRIVATE_KEY_B64 (optional; base64 raw 32-byte key)
"""
import base64
import hashlib
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple

REPO_ROOT = Path(__file__).resolve().parents[3]
CI_DIR = REPO_ROOT / "ci"
TESTS_DIR = CI_DIR / "tests"
COV_DIR = CI_DIR / "coverage"
PROV_DIR = REPO_ROOT / ".provenance"
FRONT_PAGE_PML = CI_DIR / "front_page.pml"
SUMMARY_JSON = TESTS_DIR / "summary.json"
FAILURES_MD = TESTS_DIR / "failures.md"
COVERAGE_JSON = COV_DIR / "coverage.json"
MANIFEST_JSON = PROV_DIR / "manifest.json"
MANIFEST_SIG = PROV_DIR / "manifest.json.sig"

CRATE_PKG = "switchyard-fs"

@dataclass
class TestSummary:
    total: int
    passed: int
    failed: int
    duration_seconds: float
    failure_lines: List[str]


def sh(cmd: List[str], cwd: Optional[Path] = None, check: bool = True) -> Tuple[int, str, str]:
    p = subprocess.Popen(cmd, cwd=str(cwd) if cwd else None, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    out, err = p.communicate()
    if check and p.returncode != 0:
        sys.stderr.write(f"Command failed ({p.returncode}): {' '.join(cmd)}\n")
        sys.stderr.write(err)
        raise subprocess.CalledProcessError(p.returncode, cmd, output=out, stderr=err)
    return p.returncode, out, err


def ensure_dirs():
    for d in (CI_DIR, TESTS_DIR, COV_DIR, PROV_DIR):
        d.mkdir(parents=True, exist_ok=True)


def parse_test_output(output: str) -> TestSummary:
    # Look for a final "test result:" line from libtest
    # Example: "test result: ok. 12 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.18s"
    total_passed = 0
    total_failed = 0
    duration = 0.0
    failure_lines: List[str] = []

    for line in output.splitlines():
        if line.startswith("failures:"):
            # Collect following lines until an empty line or summary
            failure_lines.append(line)
        elif failure_lines and line.strip():
            failure_lines.append(line)
        elif failure_lines and not line.strip():
            # blank line ends failure section
            failure_lines.append("")
            failure_lines = failure_lines  # keep as-is
            # do not reset to allow multiple failure sections

        if "test result:" in line:
            # Parse counts
            # Extract segments separated by ';'
            segments = [seg.strip() for seg in line.split(';')]
            # Find passed/failed counts
            for seg in segments:
                m_pass = re.search(r"(\d+)\s+passed", seg)
                if m_pass:
                    total_passed += int(m_pass.group(1))
                m_fail = re.search(r"(\d+)\s+failed", seg)
                if m_fail:
                    total_failed += int(m_fail.group(1))
                m_dur = re.search(r"finished in\s+([0-9.]+)s", seg)
                if m_dur:
                    try:
                        duration = float(m_dur.group(1))
                    except ValueError:
                        pass

    total = total_passed + total_failed
    return TestSummary(total=total, passed=total_passed, failed=total_failed, duration_seconds=round(duration, 1), failure_lines=failure_lines)


def run_switchyard_tests() -> TestSummary:
    # Run tests for the switchyard crate only to keep scope stable
    # We avoid unstable JSON output; parse the standard summary line.
    cmd = ["bash", "-lc", f"set -euo pipefail; cargo test -p {CRATE_PKG} --quiet || true"]
    rc, out, err = sh(cmd)
    # In quiet mode, libtest still prints the final summary lines to stdout/stderr; capture both
    combined = out + "\n" + err
    summary = parse_test_output(combined)
    # If tests failed, rerun verbosely to capture failure details for failures.md (non-fatal)
    if summary.failed > 0:
        _, out2, err2 = sh(["bash", "-lc", f"set -o pipefail; cargo test -p {CRATE_PKG} 2>&1 || true"], check=False)
        summary = parse_test_output(out2 + "\n" + err2)
    return summary


def write_tests_artifacts(summary: TestSummary):
    data = {
        "total": summary.total,
        "passed": summary.passed,
        "failed": summary.failed,
        "duration_seconds": float(f"{summary.duration_seconds:.1f}")
    }
    SUMMARY_JSON.write_text(json.dumps(data, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")

    if summary.failed > 0 and summary.failure_lines:
        lines = ["# Test Failures", "", "```", *summary.failure_lines, "```", ""]
    else:
        lines = ["# Test Failures", "", "No failures detected.", ""]
    FAILURES_MD.write_text("\n".join(lines), encoding="utf-8")


def ensure_cargo_tarpaulin():
    # Detect via exit code of command -v; do not attempt installation (no external fetches)
    rc, _, _ = sh(["bash", "-lc", "command -v cargo-tarpaulin >/dev/null 2>&1"], check=False)
    if rc != 0:
        raise FileNotFoundError("cargo-tarpaulin not found in PATH")


def compute_coverage() -> Dict:
    # Use tarpaulin to produce lcov info, then compute per-file pct and total pct deterministically
    try:
        ensure_cargo_tarpaulin()
    except FileNotFoundError:
        # Tarpaulin not available; return zero coverage deterministically
        return {"total": {"pct": 0.0}, "files": []}
    # Clean previous coverage artifacts
    for p in COV_DIR.glob("*"):
        try:
            if p.is_file():
                p.unlink()
        except Exception:
            pass
    # Run tarpaulin
    sh([
        "bash", "-lc",
        f"set -euo pipefail; cargo tarpaulin -p {CRATE_PKG} --out Lcov --output-dir {COV_DIR} -q || true"
    ], check=False)
    lcov_path = COV_DIR / "lcov.info"
    files: Dict[str, Tuple[int, int]] = {}  # path -> (LF, LH)
    if lcov_path.exists():
        current_file: Optional[str] = None
        lf = 0
        lh = 0
        for raw in lcov_path.read_text(encoding="utf-8", errors="ignore").splitlines():
            if raw.startswith("SF:"):
                # Start of new source file
                if current_file is not None:
                    files[current_file] = (lf, lh)
                current_file = raw[3:].strip()
                lf = 0
                lh = 0
            elif raw.startswith("DA:"):
                # DA:<line>,<count>
                try:
                    _, count = raw[3:].split(",", 1)
                    lf += 1
                    if int(count) > 0:
                        lh += 1
                except Exception:
                    pass
            elif raw.startswith("LF:"):
                try:
                    lf = int(raw[3:].strip())
                except Exception:
                    pass
            elif raw.startswith("LH:"):
                try:
                    lh = int(raw[3:].strip())
                except Exception:
                    pass
            elif raw.strip() == "end_of_record":
                if current_file is not None:
                    files[current_file] = (lf, lh)
                    current_file = None
        # Flush last file if not closed
        if current_file is not None:
            files[current_file] = (lf, lh)
    # Build coverage JSON shape
    file_rows: List[Dict] = []
    total_lf = 0
    total_lh = 0
    for path, (lf, lh) in files.items():
        total_lf += lf
        total_lh += lh
        pct = 0.0 if lf == 0 else round((lh / max(lf, 1)) * 100.0, 1)
        # Normalize to repo-relative paths when possible
        try:
            rel = str(Path(path).resolve().relative_to(REPO_ROOT))
        except Exception:
            rel = path
        file_rows.append({"path": rel, "pct": float(f"{pct:.1f}")})
    # Deterministic ordering
    file_rows.sort(key=lambda r: r["path"]) 
    total_pct = 0.0 if total_lf == 0 else round((total_lh / max(total_lf, 1)) * 100.0, 1)
    cov = {"total": {"pct": float(f"{total_pct:.1f}")}, "files": file_rows}
    return cov


def write_coverage_artifacts(cov: Dict):
    COVERAGE_JSON.write_text(json.dumps(cov, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()


def canonicalize_json(obj: Dict) -> bytes:
    # Sort keys, compact separators, UTF-8, newline at end
    s = json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    if not s.endswith("\n"):
        s += "\n"
    return s.encode("utf-8")


def sign_ed25519(data: bytes, priv_b64: Optional[str]) -> Optional[str]:
    if not priv_b64:
        return None
    try:
        from nacl.signing import SigningKey
    except Exception:
        # PyNaCl not available
        return None
    try:
        sk_bytes = base64.b64decode(priv_b64)
        if len(sk_bytes) != 32:
            # Permit 64-byte expanded key as well
            if len(sk_bytes) == 64:
                sk_bytes = sk_bytes[:32]
            else:
                return None
        sk = SigningKey(sk_bytes)
        sig = sk.sign(data).signature
        return base64.b64encode(sig).decode("ascii")
    except Exception:
        return None


def build_manifest() -> Dict:
    repo = os.environ.get("GITHUB_REPOSITORY", "owner/repo")
    commit = os.environ.get("GITHUB_SHA", "")
    run_id = os.environ.get("GITHUB_RUN_ID", "0")
    attempt = int(os.environ.get("GITHUB_RUN_ATTEMPT", "1") or "1")
    server = os.environ.get("GITHUB_SERVER_URL", "https://github.com")
    workflow_url = f"{server}/{repo}/actions/runs/{run_id}"

    artifacts = [
        {
            "id": "tests-summary",
            "title": "Test Summary",
            "path": str(SUMMARY_JSON.relative_to(REPO_ROOT)),
            "media_type": "application/json",
            "render": "summary:test",
            "sha256": sha256_file(SUMMARY_JSON),
        },
        {
            "id": "coverage",
            "title": "Coverage",
            "path": str(COVERAGE_JSON.relative_to(REPO_ROOT)),
            "media_type": "application/json",
            "render": "table:coverage",
            "sha256": sha256_file(COVERAGE_JSON),
        },
        {
            "id": "failures",
            "title": "Failing Specs",
            "path": str(FAILURES_MD.relative_to(REPO_ROOT)),
            "media_type": "text/markdown",
            "render": "markdown",
            "sha256": sha256_file(FAILURES_MD),
        },
    ]
    manifest = {
        "version": 1,
        "repo": repo,
        "commit": commit,
        "workflow_run": {"id": int(run_id), "url": workflow_url, "attempt": attempt},
        "front_page": {"title": "QA Evidence for {{ commit }}", "markup": str(FRONT_PAGE_PML.relative_to(REPO_ROOT))},
        "artifacts": artifacts,
    }
    return manifest


def main():
    ensure_dirs()

    # Ensure front_page.pml exists (CI may generate it if missing)
    if not FRONT_PAGE_PML.exists():
        FRONT_PAGE_PML.write_text(
            """# QA Evidence for {{ commit }}\n<grid cols=3 gap=16>\n  <card title=\"Tests\"><artifact.summary id=\"tests-summary\" /></card>\n  <card title=\"Coverage\"><artifact.table id=\"coverage\" /></card>\n  <card title=\"Failures\"><artifact.markdown id=\"failures\" /></card>\n</grid>\n""",
            encoding="utf-8",
        )

    # Tests
    summary = run_switchyard_tests()
    write_tests_artifacts(summary)

    # Coverage
    cov = compute_coverage()
    write_coverage_artifacts(cov)

    # Manifest + signature
    manifest = build_manifest()
    canonical = canonicalize_json(manifest)
    MANIFEST_JSON.write_text(canonical.decode("utf-8"), encoding="utf-8")
    sig_b64 = sign_ed25519(canonical, os.environ.get("PROVENANCE_ED25519_PRIVATE_KEY_B64"))
    if sig_b64 is not None:
        MANIFEST_SIG.write_text(sig_b64 + "\n", encoding="utf-8")

    # Final echo so CI logs show a summary
    print(json.dumps({
        "tests": json.loads(SUMMARY_JSON.read_text()),
        "coverage_total_pct": json.loads(COVERAGE_JSON.read_text()).get("total", {}).get("pct", 0.0),
        "manifest_path": str(MANIFEST_JSON),
        "signature_present": bool(sig_b64),
    }, sort_keys=True))


if __name__ == "__main__":
    main()
