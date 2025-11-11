# Write-SessionIndexSummary.ps1

**Path:** `tools/Write-SessionIndexSummary.ps1`

## Synopsis
Append a concise “Session” block to the GitHub Actions step summary based on a `session-index.json` file.

## Description
- Does nothing when `GITHUB_STEP_SUMMARY` is unset (non-GitHub runs).
- Reads `<ResultsDir>/<FileName>` (defaults to `tests/results/session-index.json`).  
- When the file is missing, appends a “Session” heading with a “File: (missing …)” line.  
- When present, emits bullet lines for status, totals, pass/fail/errors, duration, file path, and selected `runContext` metadata (runner name/OS/arch/env/machine/image).  
- Helpers ensure missing fields are simply omitted, keeping the summary compact.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `ResultsDir` | string | `tests/results` | Directory containing the session index. |
| `FileName` | string | `session-index.json` | Name of the JSON file to summarize. |

## Exit Codes
- `0` — Summary appended (or skipped due to missing GITHUB_STEP_SUMMARY).
- `!=0` — Only when JSON parsing fails.

## Related
- `tools/Ensure-SessionIndex.ps1`
- `tools/Run-SessionIndexValidation.ps1`
- `tools/Run-HeadlessCompare.ps1`
