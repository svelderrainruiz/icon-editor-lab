# Detect-RogueLV.ps1

**Path:** `tools/Detect-RogueLV.ps1`

## Synopsis
Detect stray LabVIEW / LVCompare processes (“rogue” instances) and optionally fail the run or append a summary to the GitHub step report.

## Description
- Scans the process table for `LabVIEW.exe` and `LVCompare.exe`, compares them against “noticed” PIDs recorded in `_lvcompare_notice/notice-*.json` (written by LVCompare wrappers).
- Supports retries (`RetryCount`, `RetryDelaySeconds`) so transient shutdowns can settle before flagging rogues.
- Produces a payload (`rogue-lv-detection/v1`) with live/rogue PID lists, command-line details, and attempt history. Writes JSON to STDOUT and, when `-OutputPath` is set, to disk (commonly `tests/results/_agent/icon-editor/dev-mode-run/rogue-lv.json`).
- When `-AppendToStepSummary` is set and `GITHUB_STEP_SUMMARY` exists, appends a markdown summary of live/rogue processes to the job summary.
- Use `-FailOnRogue` to exit with code `3` if rogue PIDs remain after retries (used in CI guardrails described in `docs/LABVIEW_GATING.md`).

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `ResultsDir` | string | `tests/results` | Location used to discover `_lvcompare_notice` files. |
| `LookBackSeconds` | int | `900` | Window for considering notice files when determining “noticed” processes. |
| `FailOnRogue` | switch | Off | Exit with `3` if rogue PIDs remain. |
| `AppendToStepSummary` | switch | Off | Append results to the Actions summary. |
| `Quiet` | switch | Off | Suppress console output (useful when scripting). |
| `RetryCount` | int | `1` | Number of detection attempts. |
| `RetryDelaySeconds` | int | `5` | Delay between attempts when rogues are detected. |
| `OutputPath` | string | — | File path for the JSON payload. |

## Exit Codes
- `0` — No rogue processes detected (or detection report written).
- `3` — Rogue processes detected when `-FailOnRogue` is set.
- Other non-zero values bubble up from unexpected failures.

## Related
- `tools/Ensure-LabVIEWClosed.ps1`
- `tools/Close-LabVIEW.ps1`
- `docs/LABVIEW_GATING.md`
