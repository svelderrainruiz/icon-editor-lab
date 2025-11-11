# Dev-WatcherManager.ps1

**Path:** `tools/Dev-WatcherManager.ps1`

## Synopsis
Manages the Watch-Pester background process: ensure it’s running, report status, trim oversized logs, or stop/auto-trim rogue sessions.

## Description
- Maintains metadata under `<ResultsDir>/_agent/watcher/` (pid/status/heartbeat/log files).
- Modes:
  - `-Ensure` – start Watch (if not already running) and monitor heartbeats; optionally auto-trim logs after inactivity.
  - `-Stop` – gracefully terminate the Watch process and remove metadata.
  - `-Status` – emit the current pid, uptime, heartbeat age, and log sizes.
  - `-Trim` – shrink `watch.out`/`watch.err` to keep them under configured size/line limits.
- Health tracking:
  - `-WarnSeconds`, `-HangSeconds`, and `-NoProgressSeconds` emit warnings when the watcher appears stalled.
  - `-PollMs` controls heartbeat polling in ensure mode.
  - `-AutoTrim` and `-AutoTrimCooldownSeconds` automatically shorten logs when large.

### Parameters (subset)
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Ensure` / `Stop` / `Status` / `Trim` | switch | Off | Selects the manager action (can combine `Ensure` + `AutoTrim`). |
| `AutoTrim` | switch | Off | Enable periodic trimming while ensuring the watcher. |
| `ResultsDir` | string | `tests/results` | Root containing `_agent/watcher/`. |
| `WarnSeconds` | int | `60` | Threshold for warning when no heartbeat. |
| `HangSeconds` | int | `120` | Threshold for hang detection (forces restart). |
| `PollMs` | int | `2000` | Heartbeat poll interval when ensuring. |
| `NoProgressSeconds` | int | `90` | Detects lack of new log lines. |
| `ProgressRegex` | string | `^(?:\s*\[-+\*\]|\s*It\s)` | Pattern used to detect progress lines when tailing logs. |
| `AutoTrimCooldownSeconds` | int | `900` | Minimum time between auto-trim operations. |

## Outputs
- `_agent/watcher/` metadata files (`pid.json`, `watch.out`, `watch.err`, `watcher-status.json`, etc.) and console diagnostics describing actions taken.

## Exit Codes
- `0` on success; non-zero for unrecoverable failures (unable to spawn/stop Watch, log access errors).

## Related
- `tools/Watch-Pester.ps1`
- `docs/LABVIEW_GATING.md`
