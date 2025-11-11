# Write-PesterTopFailures.ps1

**Path:** `tools/Write-PesterTopFailures.ps1`

## Synopsis
Summarize the most recent Pester failures and append them to `GITHUB_STEP_SUMMARY`.

## Description
- Looks for `pester-failures.json` under `-ResultsDir` (default `tests/results`). When absent, falls back to parsing `pester-results.xml` (NUnit format) to extract failed test cases.
- Prints up to `-Top` failures (default 5), showing test name and file/line when available; each entry is a markdown bullet with an optional message line.
- No-op when `GITHUB_STEP_SUMMARY` is unset, so local runs don’t break.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `ResultsDir` | string | `tests/results` | Location of Pester result files. |
| `Top` | int | `5` | Maximum number of failures to list. |

## Outputs
- Markdown appended to `GITHUB_STEP_SUMMARY` (`### Top Failures …`).

## Related
- `tests/results/pester-failures.json`
- `tests/results/pester-results.xml`
