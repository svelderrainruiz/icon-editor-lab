# TestStand-CompareHarness.ps1

**Path:** `tools/TestStand-CompareHarness.ps1`

## Synopsis
Core LVCompare harness: warm up LabVIEW, run `Invoke-LVCompare`, and emit a `session-index.json` + compare artifacts used by run reports and Scenario 1‑4.

## Description
- Imports LabVIEW/Vendor helper modules, validates paths, and stages support scripts (Warmup-LabVIEWRuntime, Invoke-LVCompare, close helpers).
- Workflow:
  1. Optionally warm up LabVIEW (`Warmup = detect`/`spawn`/`skip`).
  2. Call `Invoke-LVCompare.ps1` with the chosen flags/noise profile to produce `compare/lvcompare-capture.json`.  
  3. Record warnings (missing capture, warmup skipped, CLI errors) and write `<OutputRoot>/session-index.json` (`teststand-compare-session/v1`) summarizing inputs, CLI command, exit code, and logs.  
  4. Optionally run `Close-LabVIEW.ps1` and `Close-LVCompare.ps1`.
- Supports additional metadata: `ReportLabel`, `LogPath`, `StagingRoot`, `SameNameHint`, etc., which feed LVCompare run reports (`tools/report/New-LVCompareReport.ps1`).

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `BaseVi` / `HeadVi` | string (required) | — | Absolute (or staged) VI paths. |
| `LabVIEWExePath` | string | auto | Override when multiple installs are present. |
| `LVComparePath` | string | auto | Explicit LVCompare.exe path. |
| `OutputRoot` | string | `tests/results/teststand-session` | Destination for compare artifacts/session index. |
| `Warmup` | string (`detect`,`spawn`,`skip`) | `detect` | Controls warmup helper behaviour. |
| `Flags` | string[] | default harness flags | Additional LVCompare CLI flags. |
| `ReplaceFlags` | switch | Off | Replace, rather than append to, the default flags. |
| `RenderReport` | switch | Off | Request `compare-report.html`. |
| `NoiseProfile` | string (`full`,`legacy`) | `full` | Select ignore bundle. |
| `CloseLabVIEW` / `CloseLVCompare` | switch | Off | Run close scripts after compare. |
| `ReportLabel` | string | Auto label | Used by LVCompare run reports. |
| `LogPath` | string | `INVOCATION_LOG_PATH` | Transcript recorded in reports. |
| `SkipCliCapture` | switch | Off | Honor `COMPAREVI_NO_CLI_CAPTURE` flows (Scenario 3). |
| `AllowSameLeaf` / `SameNameHint` | switch | Off | Informs run reports when same-name VIs are compared. |
| `WarmupLabel` / `ComparePolicy` / `Mode` | string | — | Extra metadata recorded in session index/report. |

## Exit Codes
- `0` — Compare succeeded (or diff produced); see session index for `diff` flag.
- `!=0` — CLI errors, warmup timeout, or capture missing (warnings recorded in session index).

## Related
- `tools/Run-HeadlessCompare.ps1`
- `tools/Stage-CompareInputs.ps1`
- `tools/report/New-LVCompareReport.ps1`
- `docs/LVCOMPARE_LAB_PLAN.md`
