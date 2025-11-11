# Read-EnvSettings.ps1

**Path:** `tools/Read-EnvSettings.ps1`

## Synopsis
Prints (or JSON-serializes) the repo’s runtime environment toggles (`DETECT_LEAKS`, `CLEAN_AFTER`, `LV_SUPPRESS_UI`, etc.) using sensible defaults.

## Description
- Reads a handful of environment variables and converts them to booleans via `Get-Bool`. Defaults are hardcoded in the script (e.g., leak detection enabled, watch console output on).
- Output is either a PSCustomObject (human-readable) or JSON when `-Json` is supplied; fields include `detectLeaks`, `cleanAfter`, `unblockGuard`, `suppressUi`, `watchConsole`, `invokerRequired`, and `labviewExe`.
- Used by watcher utilities and CI debug scripts to quickly inspect what toggles are active for the current job.

### Parameters
| Name | Type | Default |
| --- | --- | --- |
| `Json` | switch | Off |

## Outputs
- PSCustomObject or JSON describing the effective environment settings.

## Related
- `tools/WatcherInvoker.ps1`
- `docs/LABVIEW_GATING.md`
