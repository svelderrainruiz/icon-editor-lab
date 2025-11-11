# Emit-LVClosureCrumb.ps1

**Path:** `tools/Emit-LVClosureCrumb.ps1`

## Synopsis
Appends LabVIEW/LVCompare process telemetry (“crumbs”) to `_diagnostics/lv-closure.ndjson` when `EMIT_LV_CLOSURE_CRUMBS` is enabled.

## Description
- Checks `EMIT_LV_CLOSURE_CRUMBS` in the environment; exits immediately if falsey.
- Captures basic metadata (name, pid, start time, window title) for each process in `-ProcessNames` (default `LabVIEW`, `LVCompare`).
- Writes a JSON line (`lv-closure/v1`) containing `phase`, `generatedAtUtc`, host/job info, process count, and process list to `<ResultsDir>/_diagnostics/lv-closure.ndjson` (directories auto-created).
- Intended to be invoked before/after critical steps (e.g., close events) so the orchestrator can confirm LabVIEW closure timing.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `ResultsDir` | string | `tests/results` | Root where `_diagnostics/lv-closure.ndjson` resides. |
| `Phase` | string | `unknown` | Label describing when the crumb was captured (e.g., `before-close`, `after-close`). |
| `ProcessNames` | string[] | `LabVIEW, LVCompare` | Additional process names to record. |

## Outputs
- Appends JSON lines to `tests/results/_diagnostics/lv-closure.ndjson`.

## Exit Codes
- Always `0` (even on telemetry errors the script logs a warning and exits success to avoid breaking pipelines).

## Related
- `tools/Capture-LabVIEWSnapshot.ps1`
- `docs/LABVIEW_GATING.md`
