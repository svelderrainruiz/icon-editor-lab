# Invoke-WithTranscript.ps1

**Path:** `tools/Invoke-WithTranscript.ps1`

## Synopsis
Runs an arbitrary command under PowerShell’s transcript facility and stores the log under `tests/results/_agent/logs`.

## Description
- Creates (if needed) `tests/results/_agent/logs`, sanitizes the requested `-Label`, and writes a timestamped `<label>-yyyyMMddTHHmmssfff.log`.
- Sets `INVOCATION_LOG_PATH` for the duration of the child command so downstream helpers know where to append messages.
- Captures the target command’s exit code, rethrows any exception, and always prints the final `logPath=` line to simplify GH workflow outputs.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Label` | string (required) | - | Used to name the transcript file (invalid characters become `-`). |
| `Command` | string (required) | - | Executable or script to invoke. |
| `Arguments` | string[] | - | Optional additional arguments passed to `Command`. |
| `WorkingDirectory` | string | Current directory | Pushes into this directory before invoking the command. |

## Outputs
- Transcript log at `tests/results/_agent/logs/<label>-<timestamp>.log` plus the console `logPath=...` line.
- Propagates the exit code from `Command` so CI can gate on its success/failure.

## Exit Codes
- `0` – Command completed successfully (or returned 0).
- `!=0` – Command failed or threw; the script bubbles up the same failure after stopping the transcript.

## Related
- `tools/Print-AgentHandoff.ps1`
- `docs/LABVIEW_GATING.md`
