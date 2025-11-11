# Run-HeadlessCompare.ps1

**Path:** `tools/Run-HeadlessCompare.ps1`

## Synopsis
CLI-first wrapper for TestStand-CompareHarness: stages inputs, enforces LabVIEW 2025 x64 preflight, runs LVCompare, and emits `compare-report.html`, capture JSON, and `session-index.json`.

## Description
- Sets safe LabVIEW environment flags (`LV_SUPPRESS_UI`, `LV_NO_ACTIVATE`, etc.) and resolves LVCompare/LabVIEWCLI paths via `Resolve-LabVIEW2025Environment` or `-LabVIEWExePath`.
- Unless `-UseRawPaths` is set, stages the base/head VIs with `Stage-CompareInputs.ps1`, preserving metadata for the harness.
- Invokes `tools/TestStand-CompareHarness.ps1` with warmup profile, report, noise profile, and output root parameters.
- Applies timeout guards (warmup + compare) unless `-DisableTimeout` is specified.
- Outputs:
  - `<OutputRoot>/compare-report.html` (when `-RenderReport`)
  - `<OutputRoot>/compare/lvcompare-capture.json`
  - `<OutputRoot>/session-index.json` (`teststand-compare-session/v1`)

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `BaseVi` / `HeadVi` | string (required) | — | Paths to the VIs being compared. |
| `OutputRoot` | string | `tests/results/headless-compare` | Directory receiving all harness outputs. |
| `WarmupMode` | string (`detect`,`spawn`,`skip`) | `skip` | for harness warmup behaviour. |
| `RenderReport` | switch | Off | Request HTML compare report. |
| `NoiseProfile` | string (`full`,`legacy`) | `full` | Controls LVCompare ignore bundle. |
| `TimeoutSeconds` | int | `600` | Timeout for warmup + compare. |
| `DisableTimeout` | switch | Off | Disable timeout enforcement. |
| `DisableCleanup` | switch | Off | When set, skip harness cleanup (LabVIEW/LVCompare close). |
| `UseRawPaths` | switch | Off | Skip staging and pass the raw VI paths to the harness. |
| `LabVIEWExePath` | string | Auto-resolved | Explicit LabVIEW 2025 x64 path; required if auto resolution fails. |

## Exit Codes
- `0` — Compare completed; inspect `session-index.json` for status.
- `!=0` — Harness or warmup failed (error message indicates stage).

## Related
- `tools/TestStand-CompareHarness.ps1`
- `tools/Stage-CompareInputs.ps1`
- `docs/LVCOMPARE_LAB_PLAN.md`
