# Follow-PesterArtifacts.ps1

**Path:** `tools/Follow-PesterArtifacts.ps1`

## Synopsis
Tails Pester dispatcher logs and summary JSON, using either a Node-based watcher (`follow-pester-artifacts.mjs`) or a PowerShell fallback, to detect hang/no-progress conditions during long-running suites.

## Description
- Watches `<ResultsDir>/<LogFile>` (default `tests/results/pester-dispatcher.log`) and `<ResultsDir>/<SummaryFile>` for updates; the Node watcher handles hang detection, progress regex matching, and exit conditions.
- Automatically chooses the Node watcher when available; `-ForcePowerShell` forces the PowerShell tails, while `-PreferNodeWatcher` or `PREFERRED_PESTER_WATCHER` controls preference.
- Health options:
  - `-WarnSeconds` and `-HangSeconds` emit warnings when no updates are seen.
  - `-NoProgressSeconds` + `-ProgressRegex` detect when log lines stop matching “progress” output.
  - `-ExitOnHang` / `-ExitOnNoProgress` (Node watcher only) cause non-zero exits when thresholds are exceeded.
- `-Tail` prints the last N lines on startup; `-Quiet` suppresses incremental output.

### Parameters (subset)
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `ResultsDir` | string | `tests/results` | Root containing log/summary files. |
| `LogFile` | string | `pester-dispatcher.log` | Relative log file path under `ResultsDir`. |
| `SummaryFile` | string | `pester-summary.json` | Summary JSON to monitor. |
| `Tail` | int | `40` | Number of log lines shown on startup. |
| `SkipSummaryWatch` | switch | Off | Skip summary file monitoring. |
| `PreferNodeWatcher` / `ForcePowerShell` | switch | Off | Control watcher implementation. |
| `WarnSeconds` | int | `90` | Warning threshold for inactivity. |
| `HangSeconds` | int | `180` | Hang threshold (Node watcher fail-fast when paired with `-ExitOnHang`). |
| `PollMs` | int | `10000` | Polling interval for watchers. |
| `NoProgressSeconds` | int | `0` | Engage progress regex tracking. |
| `ProgressRegex` | string | `^(?:\s*\[-+\*\]|\s*It\s)` | Pattern matching progress output. |
| `ExitOnHang` / `ExitOnNoProgress` | switch | Off | Cause Node watcher to exit non-zero on stale conditions. |

## Exit Codes
- `0` when monitoring finishes cleanly.
- Propagates Node watcher exit codes when fail-fast options are triggered or when the PowerShell tail encounters errors.

## Related
- `tools/dev/Dev-WatcherManager.ps1`
- `tools/Watch-Pester.ps1`
