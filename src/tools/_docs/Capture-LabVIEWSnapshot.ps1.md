# Capture-LabVIEWSnapshot.ps1

**Path:** `tools/Capture-LabVIEWSnapshot.ps1`

## Synopsis
Captures a JSON snapshot of running `LabVIEW.exe` and `LVCompare.exe` processes for diagnostics/warmup telemetry.

## Description
- Enumerates active LabVIEW/LVCompare processes (best-effort) and records PID, start time, CPU seconds, working set, private bytes, and responsiveness.
- Writes the snapshot to `tests/results/_warmup/labview-processes.json` by default (directories are auto-created). The schema is `labview-process-snapshot/v1`.
- Designed to run before/after warmups so CI can make informed decisions about closing or reusing LabVIEW.
- `-Quiet` suppresses `[labview-snapshot]` console logs.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `OutputPath` | string | `tests/results/_warmup/labview-processes.json` | Destination JSON file (absolute or relative). |
| `Quiet` | switch | Off | Suppress progress logging. |

## Outputs
- JSON snapshot with top-level counts plus detailed process objects for LabVIEW and LVCompare.

## Exit Codes
- `0` on success (missing processes are treated as empty arrays, not errors).
- Non-zero if the snapshot file cannot be written.

## Related
- `tools/Close-LabVIEW.ps1`
- `docs/LABVIEW_GATING.md`
