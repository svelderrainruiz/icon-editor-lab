# Write-FixtureValidationSummary.ps1

**Path:** `tools/Write-FixtureValidationSummary.ps1`

## Synopsis
Render a markdown summary of fixture validation results (current snapshot + delta) and append it to `GITHUB_STEP_SUMMARY`.

## Description
- Reads `fixture-validation.json` and `fixture-validation-delta.json` (paths configurable via `-ValidationJson` / `-DeltaJson`).
- Summarizes current snapshot counts (missing, untracked, hashMismatch, etc.) and whether validation succeeded.
- For the delta file it lists changed categories, number of new structural issues, and whether the run should fail (`willFail`).
- When `SUMMARY_VERBOSE=true`, includes detailed change listings and per-issue breakdowns.
- Defaults `SummaryPath` to `GITHUB_STEP_SUMMARY` but can write to any file for offline review.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `ValidationJson` | string | `fixture-validation.json` | Current snapshot JSON path. |
| `DeltaJson` | string | `fixture-validation-delta.json` | Delta JSON path. |
| `SummaryPath` | string | `$env:GITHUB_STEP_SUMMARY` | Destination markdown file; falls back to console when unset. |

## Outputs
- Markdown summary appended to the specified summary file (or printed).

## Related
- `tools/Test-FixtureValidationDeltaSchema.ps1`
- `tools/Validate-Fixtures.ps1`
