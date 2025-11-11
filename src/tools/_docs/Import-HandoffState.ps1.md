# Import-HandoffState.ps1

**Path:** `tools/priority/Import-HandoffState.ps1`

## Synopsis
Loads the latest agent handoff artifacts (`tests/results/_agent/handoff/*.json`) and surfaces them in the console/global variables for follow-up workflows.

## Description
- Reads JSON files such as `issue-summary.json`, `issue-router.json`, `hook-summary.json`, `watcher-telemetry.json`, `release-summary.json`, and `test-summary.json`.
- Prints a concise summary for each file (standing priority issue, router actions, hook plane statuses, watcher telemetry presence, SemVer validity, test results).
- Stores the deserialized objects in global variables (`StandingPrioritySnapshot`, `HookHandoffSummary`, `ReleaseHandoffSummary`, etc.) so subsequent scripts can reuse them without re-reading disk.
- Safe to run even when the handoff directory is missing; emits warnings instead of failing.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `HandoffDir` | string | `tests/results/_agent/handoff` | Directory containing handoff JSON files. |

## Exit Codes
- Always `0`; missing files simply produce notices.

## Related
- `tools/priority/Export-HandoffState.ps1`
- `tools/Get-StandingPriority.ps1`
