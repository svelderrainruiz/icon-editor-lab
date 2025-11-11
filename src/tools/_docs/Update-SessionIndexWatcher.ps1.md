# Update-SessionIndexWatcher.ps1

**Path:** `tools/Update-SessionIndexWatcher.ps1`

## Synopsis
Merge a watcher summary (e.g., REST watcher JSON) into `session-index.json` and extend the step summary with watcher status.

## Description
- Accepts a `WatcherJson` file (produced by `tools/Watch-OrchestratedRest.ps1` or similar).  
- Ensures `session-index.json` exists in `ResultsDir`, creating a fallback via `Ensure-SessionIndex.ps1` if necessary.
- Parses both JSON files, inserts/updates `sessionIndex.watchers.rest` with the watcher payload, and appends watcher info to the `stepSummary`.
- Helpful for surfacing orchestration watcher status alongside the main test session.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `ResultsDir` | string | `tests/results` | Directory containing `session-index.json`. |
| `WatcherJson` | string (required) | — | REST watcher summary JSON. |

## Exit Codes
- `0` — Watcher data merged or skipped (if watcher file missing).
- `!=0` — Only raised if parsing fails and cannot be recovered (warnings are logged otherwise).

## Related
- `tools/Watch-OrchestratedRest.ps1`
- `tools/Ensure-SessionIndex.ps1`
- `docs/LVCOMPARE_LAB_PLAN.md`
