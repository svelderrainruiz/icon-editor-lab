# Traceability-Matrix.ps1

**Path:** `tools/Traceability-Matrix.ps1`

## Synopsis
Generate a requirements/ADR trace matrix by correlating annotated `*.Tests.ps1` files with their latest Pester results.

## Description
- Recursively scans `TestsPath` for `*.Tests.ps1`, parses inline annotations (`REQ:XYZ`, `ADR:1234`, or `# trace:` headers), and builds a slug for each file.
- Loads requirement metadata from `docs/requirements` and ADR cards from `docs/adr`, then inspects `<ResultsRoot>/pester/<slug>/pester-results.xml` to determine whether each test passed, failed, or lacks data.
- Produces `trace-matrix.json` (`trace-matrix/v1`) that captures summary counts, per-requirement and per-ADR coverage, uncovered tests/requirements, and any unknown identifiers.
- With `-RenderHtml`, also renders `trace-matrix.html`, a reviewer-friendly report with color-coded chips linking requirements/ADRs to their covering test files.
- Designed to support SRS/ISO traceability gates before shipping bundles.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `TestsPath` | string | `tests` | Root directory searched for `*.Tests.ps1`. |
| `ResultsRoot` | string | `tests/results` | Location of Pester output folders. |
| `OutDir` | string | `<ResultsRoot>/_trace` | Destination for JSON/HTML artifacts. |
| `IncludePatterns` | string[] | — | Wildcard filter applied to test file names. |
| `RunId` | string | — | Optional identifier stored in the summary. |
| `Seed` | string | — | Arbitrary metadata captured in the summary. |
| `RenderHtml` | switch | Off | Emit `trace-matrix.html` beside the JSON. |

## Outputs
- `<OutDir>/trace-matrix.json` (`trace-matrix/v1`) containing summary, coverage nodes, and gap lists.
- `<OutDir>/trace-matrix.html` when `-RenderHtml` is specified.

## Exit Codes
- `0` — Matrix generated successfully.
- `!=0` — Failed to parse metadata, collect results, or write the artifacts.

## Related
- `docs/requirements/Icon-Editor-Lab_SRS.md`
- `docs/adr/*.md`
- `tests/README.md` (Pester conventions)
