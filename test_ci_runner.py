#!/usr/bin/env python3
"""
Minimal CI test runner for the Switchyard crate.

Usage examples:
  python3 test_ci_runner.py -p switchyard-fs --nocapture
  python3 test_ci_runner.py --golden all --nocapture

Notes:
- --golden is currently a no-op placeholder that simply runs tests.
- This script expects `cargo` to be available in PATH (install via Rust toolchain action in CI).
"""
import argparse
import subprocess
import sys
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description="Switchyard CI test runner")
    parser.add_argument("-p", "--package", default="switchyard-fs", help="Cargo package to test (default: switchyard-fs)")
    parser.add_argument("--nocapture", action="store_true", help="Pass --nocapture to cargo test")
    parser.add_argument("--golden", nargs="?", default=None, help="Golden scenario name or 'all' (currently a no-op placeholder)")
    args, unknown = parser.parse_known_args()

    # Determine repo root (current file's parent)
    repo_root = Path(__file__).resolve().parent

    # Build cargo test command
    cmd = ["cargo", "test", "-p", args.package]

    # Forward any extra args before the double dash
    if unknown:
        cmd.extend(unknown)

    # Append test harness args
    if args.nocapture:
        cmd.extend(["--", "--nocapture"])  # pass through to libtest

    if args.golden is not None:
        print(f"[ci-runner] --golden={args.golden} requested; running tests as placeholder (no-op)", file=sys.stderr)

    print(f"[ci-runner] Running: {' '.join(cmd)}", file=sys.stderr)
    try:
        return subprocess.call(cmd, cwd=str(repo_root))
    except FileNotFoundError:
        print("error: 'cargo' not found in PATH. Ensure Rust toolchain is installed.", file=sys.stderr)
        return 127


if __name__ == "__main__":
    raise SystemExit(main())
