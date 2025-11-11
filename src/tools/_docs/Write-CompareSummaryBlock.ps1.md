# Write-CompareSummaryBlock.ps1

**Path:** `tools/Write-CompareSummaryBlock.ps1`

## Synopsis
Append a short “Compare VI” block to the GitHub Actions step summary using data from `compare-summary.json`.

## Description
- Reads the compare summary JSON (default `compare-artifacts/compare-summary.json`) produced by `TestStand-CompareHarness`.
- When the file exists and parses, writes lines such as `Diff: true/false`, `ExitCode`, `Duration (s)`, `Mode`, and a pointer to the summary file.
- When the file is missing or invalid, records a “(missing)” or “failed to parse” message instead, making CI results easier to scan.
- No-op when `GITHUB_STEP_SUMMARY` is not set.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Path` | string | `compare-artifacts/compare-summary.json` | Source JSON written by the harness. |
| `Title` | string | `Compare VI` | Heading used in the summary block. |

## Exit Codes
- `0` — Block appended or skipped (non-GitHub run).
- `!=0` — Only thrown if parsing/writing fails unexpectedly.

## Related
- `tools/TestStand-CompareHarness.ps1`
- `tools/Run-HeadlessCompare.ps1`
- `tools/report/New-LVCompareReport.ps1`
