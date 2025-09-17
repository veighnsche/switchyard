# Provenance Integration Prompt — Add‑on for IDE AI (framework‑agnostic)

Add‑on prompt: append this to your existing IDE/system prompt when integrating a production‑ready repository with Provenance. Do not change the project’s language, test framework, or coding style. Your scope is limited to producing and publishing the evidence and metadata required by Provenance using the project’s existing tests/CI.

Objective: make the repository emit the required artifacts, front‑page Proofdown, signed manifest, and deterministic outputs so Provenance can render/verifiably mirror the evidence.

---

## Ground Rules (must follow)

- Source of truth: a single manifest at `.provenance/manifest.json` signed with Ed25519; signature stored at `.provenance/manifest.json.sig` (Base64). Unknown or unsigned manifests must fail verification.
- Every artifact used in views is listed in the manifest with `sha256`. Unlisted artifacts must not be rendered or linked.
- Proofdown front page (`ci/front_page.pml`) is rendered with a whitelisted component set only; unknown components/attributes are hard errors. Artifact references must use `id` (not paths).
- Minimum viewers: `markdown`, `json`, `table:coverage`, `summary:test`, `image`. Unknown `render` values error or fall back per spec.
- Determinism: identical inputs yield byte‑identical outputs (HTML and badges). Avoid time/random/non‑deterministic ordering.
- Security: no external fetches in tests/build; no secrets in repo; path traversal is rejected.

---

## Integration Checklist (framework‑agnostic)

Use your existing test runner/coverage tools. Do not switch frameworks. Implement the following outputs and publishing steps:

1) Testing artifacts (repo‑relative paths are recommendations; adjust as needed)
   - Tests summary JSON (id: `tests-summary`, render: `summary:test`)
     - Recommended path: `ci/tests/summary.json`
     - Shape:

       ```json
       { "total": 120, "passed": 118, "failed": 2, "duration_seconds": 45.6 }
       ```

   - Coverage JSON (id: `coverage`, render: `table:coverage`)
     - Recommended path: `ci/coverage/coverage.json`
     - Shape:

       ```json
       { "total": { "pct": 85.2 }, "files": [ { "path": "src/file.ext", "pct": 92.1 } ] }
       ```

   - Failures Markdown (optional; id: `failures`, render: `markdown`)
     - Recommended path: `ci/tests/failures.md`

2) Front page Proofdown
   - Create `ci/front_page.pml` that references artifacts by `id` only, e.g.:

     ```pml
     # QA Evidence for {{ commit }}
     <grid cols=3 gap=16>
       <card title="Tests">
         <artifact.summary id="tests-summary" />
         [[a:tests-summary | Full Summary]]
       </card>
       <card title="Coverage">
         <artifact.table id="coverage" />
       </card>
       <card title="Failures">
         <artifact.markdown id="failures" />
       </card>
     </grid>
     ```

3) Provenance manifest and digests
   - Create `.provenance/manifest.json` with required fields:
     - `version`, `repo` ("owner/repo"), `commit` (full SHA), `workflow_run` (`id`, `url`, `attempt`), `front_page.{title,markup}`
     - `artifacts[]`: `{ id, title, path, media_type, render, sha256 }`
   - Compute SHA‑256 for each artifact file (hex, lowercase) and populate `sha256`.

4) Sign the manifest
   - Canonicalize JSON (parse → sort keys → JSON serialize UTF‑8 with `\n` newlines).
   - Sign canonical bytes with Ed25519; write Base64 signature to `.provenance/manifest.json.sig`.

5) Publish (commit‑pinned)
   - Publish the manifest + signature + artifacts to a commit‑pinned location (e.g., GitHub Raw for the commit SHA). Do not serve dynamic/unpinned content.

6) Determinism & safety
   - Ensure outputs are byte‑stable (no timestamps/random order); sanitize text; never render or link resources not listed in the manifest.

---

## Ongoing Maintenance (when behavior changes)

- Keep emitting the three evidence artifacts in stable locations: tests summary JSON, coverage JSON, and optional failures Markdown.
- Update `ci/front_page.pml` to reflect the latest evidence and continue referencing artifacts by `id` only.
- Update `.provenance/manifest.json` when artifacts are added/removed or paths change; recompute `sha256` for changed artifacts only.
- Canonicalize the manifest and re‑sign to refresh `.provenance/manifest.json.sig`.
- Publish the updated manifest + signature + artifacts to the same commit‑pinned location used by your deployment.
- Preserve determinism (stable ordering/formatting) and component safety (whitelisted Proofdown components, validated attributes).
- If exposing badges or a Worker, ensure values are derived only from verified inputs.

---

## Acceptance Gates (must pass)

- Manifest:
  - Contains required fields and is canonicalized before signing; `.sig` verifies with Ed25519 over the canonical bytes.
- Artifacts:
  - SHA‑256 verified before rendering or linking; unknown `id` rejected.
- Proofdown:
  - Parser accepts only whitelisted components; unknowns/invalid attrs are hard errors.
- Output:
  - Deterministic: repeated runs with identical inputs yield byte‑identical outputs (HTML and badges).
- Badges:
  - If produced, JSON shape is `{ "schemaVersion": 1, "label": "...", "message": "...", "color": "..." }`; values derived only from verified inputs.
- Accessibility (baseline):
  - Headings, `<nav>` landmarks, tables with `<thead>`, `<tbody>`, and `scope`.

---

## Required Files and Shapes

Minimum repository additions (paths are recommendations; manifest `path` fields decide the truth):

- `.provenance/manifest.json` (signed index)
- `.provenance/manifest.json.sig` (Base64 Ed25519 signature of canonical bytes)
- `ci/front_page.pml` (Proofdown front page)
- `ci/tests/summary.json` (tests summary JSON)
- `ci/coverage/coverage.json` (coverage JSON)
- `ci/tests/failures.md` (optional Markdown)

Manifest skeleton:

```json
{
  "version": 1,
  "repo": "owner/repo",
  "commit": "<full-commit-sha>",
  "workflow_run": { "id": 123, "url": "https://github.com/...", "attempt": 1 },
  "front_page": { "title": "QA Evidence for {{ commit }}", "markup": "ci/front_page.pml" },
  "artifacts": [
    { "id": "tests-summary", "title": "Test Summary", "path": "ci/tests/summary.json", "media_type": "application/json", "render": "summary:test", "sha256": "<hex>" },
    { "id": "coverage", "title": "Coverage", "path": "ci/coverage/coverage.json", "media_type": "application/json", "render": "table:coverage", "sha256": "<hex>" },
    { "id": "failures", "title": "Failing Specs", "path": "ci/tests/failures.md", "media_type": "text/markdown", "render": "markdown", "sha256": "<hex>" }
  ]
}
```

Proofdown snippet:

```pml
# QA Evidence for {{ commit }}
<grid cols=3 gap=16>
  <card title="Tests"><artifact.summary id="tests-summary" /></card>
  <card title="Coverage"><artifact.table id="coverage" /></card>
  <card title="Failures"><artifact.markdown id="failures" /></card>
</grid>
```

## Publishing & CI

- Produce artifacts during your existing test/coverage jobs.
- Compute SHA‑256 and update the manifest as a distinct CI step.
- Canonicalize and sign the manifest; store only the public key in deployment.
- Publish manifest + signature + artifacts to a commit‑pinned location (e.g., GitHub Raw at the commit SHA, or an equivalent static snapshot).
- Treat any verification failure as a hard error in CI.

## Optional: Worker & Badges

- If you deploy the Cloudflare Worker, configure env: `RAW_BASE_URL`, `INDEX_PATH`, `INDEX_SIG_PATH`, `INDEX_PUBKEY_ED25519`.
- Worker routes: `/`, `/fragment/{id}`, `/a/{id}`, `/download/{id}`, `/health`, `/badge/{kind}.json|.svg`.
- Badges must derive only from verified inputs; unknown `kind` or missing artifacts → error badge.

## Troubleshooting (generic)

- Manifest verification fails → Ensure you signed canonical bytes and the public key matches; check that `sha256` values are lowercase hex and paths are repo‑relative.
- Missing or mismatched artifacts → Regenerate the JSON/Markdown artifacts, recompute `sha256`, and update the manifest entries.
- Unknown Proofdown component/attribute → Use only documented components and attributes; reference artifacts by `id` rather than by path.
- Non‑deterministic output → Sort collections before rendering, avoid timestamps/random data, and pin numeric formatting.

---

## Repository Map (what you add)

- `.provenance/` — signed manifest + signature
- `ci/` — Proofdown front page and test/coverage artifacts
- Existing code/tests/CI remain as‑is; only add/transform outputs needed for Provenance

---

## Don’ts

- Do not render or link resources not listed in the verified manifest.
- Do not reference artifacts by path in Proofdown components; always use `id`.
- Do not introduce non‑determinism (timestamps, random ordering, unstable maps).
- Do not fetch from the network during tests/build.
- Do not accept unknown Proofdown components/attributes or unrecognized `render` values silently.

---

## Getting Started (non‑prescriptive)

- Adjust your existing test runner to persist the three artifacts (tests summary JSON, coverage JSON, failures.md) in a stable location.
- Create `ci/front_page.pml` referencing the artifacts by `id` only.
- Create `.provenance/manifest.json`, compute SHA‑256 for each artifact, and sign the canonical bytes (Ed25519) to produce `.sig`.
- Ensure outputs are deterministic (sorting, stable formatting). Treat verification failures as hard errors in CI.

Follow this prompt every time: express behavior in specs and tests first, generate evidence artifacts and Proofdown, then implement or adjust code to make the tests pass and evidence verify.
