# Force-CloseLabVIEW.ps1

**Path:** `tools/Force-CloseLabVIEW.ps1`

## Synopsis
Terminates lingering LabVIEW/LVCompare processes after runs, optionally in dry-run mode, and records the result as `force-close-labview/v1`.

## Description
- Accepts one or more process names (`-ProcessName`, default `LabVIEW`,`LVCompare`) and optionally runs in `-DryRun` mode to preview what would be killed.
- Terminates matching processes via `Stop-Process -Force`, waits up to `-WaitSeconds` for them to exit, and reports any PIDs that remain.
- Outputs a JSON summary to stdout including target PIDs, remaining processes, and errors; warnings are emitted when termination fails.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `ProcessName` | string[] | `LabVIEW, LVCompare` | Process names to close. |
| `DryRun` | switch | Off | Report targets without killing them. |
| `WaitSeconds` | int | `5` | Wait time after issuing `Stop-Process`. |
| `Quiet` | switch | Off | Suppress info logs. |

## Outputs
- JSON (`force-close-labview/v1`) printed to stdout describing results (targets, errors, remaining processes).

## Exit Codes
- `0` when all targets are closed or in dry-run mode.
- `1` when processes remain or errors occur.

## Related
- `tools/Close-LabVIEW.ps1`
- `tools/Emit-LVClosureCrumb.ps1`
