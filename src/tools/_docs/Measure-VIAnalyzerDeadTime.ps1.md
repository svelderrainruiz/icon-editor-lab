# Measure-VIAnalyzerDeadTime.ps1

**Path:** `tools/icon-editor/Measure-VIAnalyzerDeadTime.ps1`

## Synopsis
Runs VI Analyzer twice (dev mode disabled vs enabled) to measure “dead time” and capture how long analyzer startup takes in each state.

## Description
- Requires a VI Analyzer config (`-ConfigPath`) and LabVIEW version/bitness. For each scenario it toggles dev mode via `Enable-DevMode.ps1`/`Disable-DevMode.ps1`, closes any running LabVIEW, runs `Invoke-VIAnalyzer.ps1 -PassThru`, and records the duration plus analyzer stats.
- Results are saved under `tests/results/_agent/vi-analyzer/deadtime/deadtime-<label>.json` using the `icon-editor/vi-analyzer-deadtime@v1` schema (entries contain scenario, duration, success flag, errors).

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `ConfigPath` | string (required) | - | VI Analyzer config to execute. |
| `LabVIEWVersion` | int | `2023` |
| `Bitness` | int (`32`,`64`) | `64` |
| `Label` | string | timestamp | Used in the output filename. |
| `ResultsDir` | string | `tests/results/_agent/vi-analyzer/deadtime` | Destination directory. |

## Outputs
- JSON summary with per-scenario entries (duration, success, analyzer results, error text if any). Path is printed at the end.

## Related
- `tools/icon-editor/Enable-DevMode.ps1`
- `tools/icon-editor/Invoke-VIAnalyzer.ps1`
- `docs/LABVIEW_GATING.md`
