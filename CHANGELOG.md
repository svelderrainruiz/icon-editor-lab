# Changelog — BL-PRE-2043-RC2

## v16.0.0 — 2025-11-15
### Highlights
- CI: coverage ≥75% global; dynamic per-file floors; artifacts uploaded on failure.
- Docs: lychee link-check with persisted report.
- Tests: expanded Pester v6 suites for heavy scripts (DocsLinks, WorkflowDrift, AgentWait, ViCompare CLI, Validate, Packaging).
- Traceability: root `adr/ADR-0001.md` and `docs/RTM.md` present.

### CI Artifacts
- `artifacts/coverage/coverage.xml` (Cobertura)
- `artifacts/test-results/results.xml` (JUnit)

### Breaking changes
- _None expected_

- RC2: Adds explicit `src/icon-editor-lab/` placeholder to ensure the bundle "has the icon-editor-lab".
- Refreshes sample artifacts and summary to target BL-PRE-2043-RC2.
