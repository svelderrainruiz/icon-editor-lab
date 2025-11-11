# Ensure-SessionIndex.ps1

**Path:** `tools/Ensure-SessionIndex.ps1`

## Synopsis
Create a fallback `session-index.json` (and minimal step summary) when a test run did not emit one.

## Description
- Accepts a `ResultsDir` (default `tests/results`) and optional `SummaryJson` (`pester-summary.json`).
- If `session-index.json` already exists under the results directory, the script exits silently.
- Otherwise it:
  - Builds a minimal JSON document (`session-index/v1`) containing timestamps, summary stats (if available), and a pointer to `pester-summary.json`.
  - Writes a short step summary block indicating total/passed/failed counts.
  - Sets `status` to `fail` when the Pester summary reports failures/errors.
- Useful in CI workflows where downstream automation expects `session-index.json` even for simple Pester runs.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `ResultsDir` | string | `tests/results` | Directory where `session-index.json` should exist. |
| `SummaryJson` | string | `pester-summary.json` | Name of the summary file to parse for totals. |

## Exit Codes
- `0` — Fallback created or already present.
- `!=0` — Only emitted when the script itself failed (exceptions bubble up).

## Related
- `tools/Run-SessionIndexValidation.ps1`
- `tools/TestStand-CompareHarness.ps1`
- `tools/report/New-LVCompareReport.ps1`
