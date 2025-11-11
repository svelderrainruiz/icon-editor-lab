# ConsoleWatch.psm1

**Path:** `tools/ConsoleWatch.psm1`

## Synopsis
Provides `Start-ConsoleWatch`/`Stop-ConsoleWatch` functions that capture console process launches (conhost, pwsh, cmd, etc.) and emit NDJSON + summary telemetry.

## Description
- `Start-ConsoleWatch -OutDir <dir> [-Targets conhost,pwsh,...]` registers a WMI `Win32_ProcessStartTrace` event listener and logs matching process launches to `<OutDir>/console-spawns.ndjson`. Falls back to a snapshot mode when event registration fails.
- `Stop-ConsoleWatch -Id <id> -OutDir <dir> [-Phase label]` unregisters the event, summarizes counts per process name, and writes `<OutDir>/console-watch-summary.json` (`console-watch-summary/v1`). In snapshot mode it diffs pre/post process lists.
- Each NDJSON record includes timestamp, pid, parent pid/name, command line (if available), and whether the process opened a window. Useful for detecting rogue consoles during dev-mode runs.

### Exported Functions
| Function | Parameters | Notes |
| --- | --- | --- |
| `Start-ConsoleWatch` | `OutDir`, `Targets` | Returns a watch id; ensures NDJSON file exists even if no events occur. |
| `Stop-ConsoleWatch` | `Id`, `OutDir`, `Phase` | Produces summary JSON and returns it to the caller. |

## Outputs
- `<OutDir>/console-spawns.ndjson`
- `<OutDir>/console-watch-summary.json`

## Related
- `tools/ConsoleWatch.ps1`
- `tools/ConsoleUx.psm1`
