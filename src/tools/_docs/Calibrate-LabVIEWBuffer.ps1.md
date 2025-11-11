# Calibrate-LabVIEWBuffer.ps1

**Path:** `tools/Calibrate-LabVIEWBuffer.ps1`

## Synopsis
Sweeps multiple LabVIEW idle buffer durations, launches LVCompare runs, and records how long LabVIEW.exe needs before it can be safely closed.

## Description
- Generates a set of buffer values from `-BufferSeconds`, `-MinBufferSeconds`, `-MaxBufferSeconds`, and `-BufferStepSeconds` (filtered by `-MaxAllowedSeconds`). Each buffer is run `-RunsPerBuffer` times.
- For every buffer:
  1. Runs `Invoke-LVCompare.ps1` against two canned VIs (with optional `-RenderReport`).
  2. Calls `Close-LabVIEW.ps1` with the candidate buffer; retries up to `-CloseRetries` with `-CloseRetryDelaySeconds` between attempts.
  3. Optionally captures new processes spawned during the run (`-CaptureProcessSnapshot`).
- Writes `tests/results/_labview_buffer_calibration/calibration-summary.json` (schema `labview-buffer-calibration/v1`) containing success counts, forced closes, and remaining PIDs per buffer. Output directories per run can be preserved via `-KeepResults`.
- `-LabVIEWExePath` lets you target a specific LabVIEW install; when `. Agent-Wait` helpers exist, the script uses them to mark waits in telemetry.

### Parameters (highlights)
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `BufferSeconds` | object[] | `@(5,10,15)` | Explicit durations to test; string/int/double accepted. |
| `MinBufferSeconds` / `MaxBufferSeconds` | int | - | Generate a range when paired with `-BufferStepSeconds`. |
| `BufferStepSeconds` | int | `5` | Increment for generated ranges; must be >0. |
| `RunsPerBuffer` | int | `3` | Number of LVCompare runs per buffer. |
| `RenderReport` | switch | Off | Request HTML report from `Invoke-LVCompare`. |
| `ResultsDir` | string | `tests/results/_labview_buffer_calibration` | Root for summaries and optional run artifacts. |
| `MaxAllowedSeconds` | int | `60` | Skip buffers above this threshold. |
| `CloseRetries` | int | `1` | Additional close attempts (after the initial wait). |
| `CloseRetryDelaySeconds` | int | `2` | Delay between close retries. |
| `LabVIEWExePath` | string | - | Explicit LabVIEW binary for cleanup. |
| `KeepResults` | switch | Off | Retain run subdirectories even on success. |
| `CaptureProcessSnapshot` | switch | Off | Record pre/post process lists for troubleshooting leaks. |
| `Quiet` | switch | Off | Suppress the console summary. |

## Outputs
- `calibration-summary.json` plus per-run directories under `<ResultsDir>/<buffer>/<run>/`.
- Optional process snapshots and `compare-leak.json` pointers when leak checking is enabled.

## Exit Codes
- `0` when all buffers complete (even if some runs fail; review the summary for details).
- Non-zero on validation failures or script exceptions (missing Invoke-LVCompare, invalid buffer settings).

## Related
- `tools/Invoke-LVCompare.ps1`
- `tools/Close-LabVIEW.ps1`
- `docs/LABVIEW_GATING.md`
