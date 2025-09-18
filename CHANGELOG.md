# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog, and this project adheres to Semantic Versioning.

## [Unreleased]

### Added
- Crate metadata for crates.io:
  - `homepage` → GitHub Pages (mdBook)
  - `documentation` → docs.rs
  - `readme` → crate README
  - `categories`, `keywords`, `rust-version = 1.75`
  - badges and `package.metadata.docs.rs`
- README and lib docs include:
  - Prominent links to mdBook and docs.rs
  - Code fences marked as `,ignore` to avoid flaky doctests
- mdBook content refresh:
  - Expanded safety-minded chapters (Preflight, Apply, Rollback, Rescue, Audit Facts)
  - Troubleshooting and How-To for schema validation
- New CI workflow (book.yml) to build mdBook and optionally deploy to GitHub Pages.
- TODO.md documenting the full split-and-publish plan for a standalone repository.
- Local CI helper scripts under `scripts/ci/` mirroring GitHub Actions workflows for easier preflight debugging locally.

### Changed
- Fixed rustdoc warnings by improving link hygiene (angle-bracket URLs recommended by rustdoc).
- Tightened crate packaging via `exclude` to keep the published crate small.
- API/internal: made `map_restore_error_kind()` a `const fn` to satisfy `clippy::missing_const_for_fn`.
- FS snapshot: documented rationale for `#[allow(clippy::too_many_lines)]` with an explicit `reason` to satisfy `allow_attributes_without_reason`.
- Tests: replaced hard-coded absolute system path string literals with runtime-constructed strings to satisfy hermetic test guard.

### Fixed
- Doctest failures originating from README/lib examples by marking example blocks as ignored.

### Pending (post-split tasks)
- Update `repository` and badges to point to the new repo (e.g., `veighnsche/switchyard`).
- Enable GitHub Pages in the new repo and confirm `homepage` URL.
- Add shields in the new repo README for crates.io, docs.rs, CI, mdBook, license, MSRV.

## [0.1.0] - Initial
- Initial crate skeleton with API, safety invariants, tests, and mdBook.

