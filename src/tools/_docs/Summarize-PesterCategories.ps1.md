# Summarize-PesterCategories.ps1

**Path:** `tools/Summarize-PesterCategories.ps1`

## Synopsis
Aggregates category-specific Pester session indices and appends an overview + per-category table to the GitHub step summary.

## Description
- For each category listed in `-Categories`, looks under `BaseDir/<category>/tests/results/session-index.json` (or `session-index.json` at the root) and extracts totals (status, total, passed, failed, errors, skipped, duration).
- Builds an overall summary plus individual lines per category; if the current GitHub run has artifacts named `orchestrated-pester-results-<category>`, links to the artifact download URL.
- Writes the formatted Markdown to `$GITHUB_STEP_SUMMARY`; exits silently when the env var isn’t set.

### Parameters
| Name | Type | Notes |
| --- | --- | --- |
| `BaseDir` | string | Root directory containing category subfolders. |
| `Categories` | string[] | Category names (subfolder names). |

## Outputs
- Markdown appended to the GitHub step summary documenting overall totals and per-category metrics.

## Related
- `tools/Run-DX.ps1`
- `tests/results/_agent/*`
