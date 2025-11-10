# Send-CtrlC.ps1

**Path:** `tools/Send-CtrlC.ps1`

## Synopsis
Attempts to send Ctrl+C (and fallback Ctrl+Break) to one or more console processes to unblock hung scripts before resorting to `Stop-Process`.

## Description
- Uses Win32 console APIs (`AttachConsole`, `GenerateConsoleCtrlEvent`) to attach to the target process and emit `CTRL_C_EVENT`, falling back to `CTRL_BREAK_EVENT` if needed.
- Supports targeting by PID or process name (`-Names` with optional `-Max` per name). `-DryRun` prints targets without sending the event.

### Parameters
| Name | Type | Default |
| --- | --- | --- |
| `Pid` | int[] | - | Direct PID(s) to signal. |
| `Names` | string[] | - | Process names (e.g., `pwsh`, `conhost`). |
| `Max` | int | `5` | Max processes per name. |
| `DryRun` | switch | Off |

## Outputs
- Console output listing targets and the number of successful Ctrl events; exit 0 even when some targets fail (script warns).

## Related
- `tools/RunnerInvoker/Start-RunnerInvoker.ps1`
