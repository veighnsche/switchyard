# Introduction

Switchyard is a Rust library for safe, atomic, and reversible filesystem swaps backed by evidence.

What it is:
- A library crate embedded by higher‑level CLIs.
- Guarantees: TOCTOU‑safe sequences, policy‑gated preflight, deterministic IDs, optional smoke with auto‑rollback, structured audit facts.

What it is not:
- A CLI manual. The guide focuses on the `switchyard` library API and its invariants.

Who this guide is for
- Operators who need a safety-first migration engine with clear recovery options.
- Integrators embedding Switchyard in packaging or system-management tools.
- Reviewers who want to verify the guarantees and trace them to SPEC and code.

Safety highlights (from SPEC)
- Atomicity: no user-visible broken or missing paths during swaps (§2.1).
- Rollback: automatic reverse-order rollback on failure; idempotent restore (§2.2).
- SafePath-only mutations and TOCTOU-safe syscall sequence (§3.3, §2.3, §2.10).
- Determinism: UUIDv5 plan/action IDs; dry-run facts byte-identical after redaction (§2.7).
- Production locking required with bounded wait and telemetry (§2.5).
- Rescue profile verification and minimal smoke suite with auto-rollback (§2.6, §2.9, §2.10, §11).
- Auditability: schema v2 JSON facts, before/after hashes, optional signed attestation (§5).

## Supported Toolchains

- Stable: 1.89.0 (continuously tested in CI) — see the announcement: https://blog.rust-lang.org/2025/08/07/Rust-1.89.0/
- MSRV: 1.81 (declared in `Cargo.toml` and enforced by the `MSRV` workflow)

Nightly and Beta channels are also exercised in CI for early signal.

Integration note
- If you are building a CLI on top (e.g., a distro tool), keep the front-end simple while Switchyard ensures safety. A common pattern is a small set of user-facing commands (e.g., use/replace/restore) with all filesystem safety delegated to Switchyard. See "CLI Integration Guidance (SafePath)" in SPEC §16.

What to read next
- Start with [Safety First](safety-first.md) to understand the invariants that protect you.
- Then follow the [Quickstart](quickstart.md) and scan the [Architecture Overview](architecture.md).

Citations:
- SPEC overview: `SPEC/SPEC.md`
- Module map: `src/`
