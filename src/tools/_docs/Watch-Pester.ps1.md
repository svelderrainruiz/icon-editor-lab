# Watch-Pester.ps1

**Path:** `tools/Watch-Pester.ps1`

## Synopsis
File watcher that runs Pester on changes, supports flaky retry telemetry, and writes watch summaries to `_watch/watch-last.json` / `watch-log.ndjson`.

## Description
- Monitors `-Path` for files matching `-Filter` (default `*.ps1`), debounces changes (`-DebounceMilliseconds`), and runs Pester (`-TestPath`, `-Tag`, `-ExcludeTag`).
- Supports delta tracking: `-DeltaJsonPath`, `-DeltaHistoryPath`, and `-MappingConfig` integrate with Watch telemetry (used by flaky demos and DevMode runs).
- Modes:
  - `-SingleRun` – run once then exit (used by CI smoke tests).
  - `-ChangedOnly` – target tests inferred from changed files or mapping config.
  - `-RerunFailedAttempts` – retry flaky tests up to N attempts (flaky demo).
- Optional notifications: `-NotifyScript`, `-BeepOnFail`, `-ShowFailed`, `-OnlyFailed`.

### Parameters (common)
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Path` | string | `.` | Root to watch. |
| `Filter` | string | `*.ps1` | File filter for changes. |
| `DebounceMilliseconds` | int | `400` | Debounce window before rerunning tests. |
| `RunAllOnStart` | switch | Off | Run tests immediately on startup. |
| `SingleRun` | switch | Off | Run once and exit (no watching). |
| `ChangedOnly` | switch | Off | Attempt to run only tests related to changed files. |
| `TestPath` | string | `tests` | Root for Pester runs. |
| `Tag` / `ExcludeTag` | string | - | Filter Pester tags. |
| `DeltaJsonPath`, `DeltaHistoryPath` | string | env-driven | Watch telemetry outputs. |
| `MappingConfig` | string | - | JSON mapping from source paths to test files. |
| `RerunFailedAttempts` | int | `0` | Flaky retry count. |
| `NotifyScript` | string | - | Script invoked after each run with status info. |

## Exit Codes
- `0` on success or when watchers stop cleanly.
- Non-zero when Pester crashes or when `SingleRun` run fails (propagates Pester exit).

## Related
- `tools/Dev-WatcherManager.ps1`
- `tools/Demo-FlakyRecovery.ps1`
