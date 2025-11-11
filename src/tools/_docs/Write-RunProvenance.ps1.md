# Write-RunProvenance.ps1

**Path:** `tools/Write-RunProvenance.ps1`

## Synopsis
Capture workflow/run metadata (refs, runner info, origin context) in `tests/results/_agent/provenance.json` and optionally append it to the step summary.

## Description
- Reads GitHub Actions env vars (`GITHUB_REF`, `GITHUB_SHA`, `GITHUB_EVENT_PATH`, runner metadata) plus optional environment overrides (`EV_ORIGIN_*`, `EV_SAMPLE_ID`, `EV_INCLUDE_INTEGRATION`, `EV_STRATEGY`).
- When event payload contains a PR, records `prNumber`, head/base refs, and author information.
- Writes an `icon-editor/report@v1`-style JSON object including repo/workflow identifiers, runner profile, branch info, and optional “origin” metadata.
- `-AppendStepSummary` adds a markdown block describing the key fields; otherwise only JSON is written.
- Honors `COMPAREVI_REPORTS_ROOT` to relocate the `tests/results/_agent/reports/<kind>` tree when necessary.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `ResultsDir` | string | `tests/results` | Base directory for `provenance.json`. |
| `FileName` | string | `provenance.json` | File name inside `ResultsDir`. |
| `AppendStepSummary` | switch | Off | Include the provenance block in `GITHUB_STEP_SUMMARY`. |

## Outputs
- `<ResultsDir>/provenance.json`
- Optional markdown appended to the step summary.

## Related
- `tools/Write-RunnerIdentity.ps1`
- `.github/workflows/*` (consumes provenance for artifacts)
