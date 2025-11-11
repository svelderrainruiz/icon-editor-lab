# Invoke-VIAnalyzer.ps1

**Path:** `tools/icon-editor/Invoke-VIAnalyzer.ps1`

## Synopsis
Headless VI Analyzer runner: launches LabVIEWCLI with a `.viancfg`/VI/folder target, captures HTML/ASCII/RSL reports, and emits telemetry JSON under `tests/results/_agent/vi-analyzer`.

## Description
- Resolves LabVIEWCLI (`LabVIEWVersion`, `Bitness`, or explicit `LabVIEWCLIPath`) and workspace/output roots.
- Runs `RunVIAnalyzer` via LabVIEWCLI, honoring report options (`ReportSaveType`, `ReportPath`, `ReportSort`, `ReportInclude`).  
- Optionally captures `.rsl` output, collects broken VI data, and writes:
  - `<OutputRoot>/<label>/vi-analyzer-report.{txt|html}`
  - `<OutputRoot>/<label>/vi-analyzer-results.rsl` (when requested)
  - `<OutputRoot>/<label>/vi-analyzer.json` (telemetry: counts, broken VIs, CLI log path).  
- Returns the telemetry object when `-PassThru` is set so callers (e.g., MissingInProject suites) can inspect failures/retry dev-mode recovery.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `ConfigPath` | string (required) | — | VI Analyzer config (VIANCfg/VI/folder/LLB). |
| `OutputRoot` | string | `tests/results/_agent/vi-analyzer` | Root folder for artifacts; run label subfolders are created automatically. |
| `Label` | string | `vi-analyzer-<timestamp>` | Used to name the run directory. |
| `ReportSaveType` | string (`ASCII`,`HTML`,`RSL`) | `ASCII` | Determines the primary report extension. |
| `LabVIEWVersion` | string | `2023` | LabVIEW install used by LabVIEWCLI resolution. |
| `Bitness` | int | `64` | LabVIEW bitness. |
| `LabVIEWCLIPath` | string | Auto-resolved | Override when LabVIEWCLI is not on PATH. |
| `CaptureResultsFile` | switch | Off | Writes `.rsl` output to `<runDir>/vi-analyzer-results.rsl`. |
| `ReportPath` / `ResultsPath` | string | Auto paths inside the run dir | Set explicit destinations for report/RSL files. |
| `ConfigPassword` | string | — | Passphrase for encrypted `.viancfg`. |
| `ReportSort` | string (`VI`,`Test`) | — | Available on newer LabVIEW versions. |
| `ReportInclude` | string[] | — | Specify result categories (FAILED, PASSED, SKIPPED). |
| `TimeoutSeconds` | int | `900` | Max wall-clock wait for LabVIEWCLI. |
| `AdditionalArguments` | string[] | — | Appended to the LabVIEWCLI command line. |
| `PassThru` | switch | Off | Return telemetry object to the caller. |

## Exit Codes
- `0` — Analyzer finished; inspect JSON for failure counts.
- `!=0` — LabVIEWCLI exited with error (bubbles up to callers).

## Related
- `tools/icon-editor/Invoke-MissingInProjectSuite.ps1`
- `tools/icon-editor/Run-MipLunit-2023x64.ps1`
- `tools/icon-editor/Run-MipLunit-2021x64.ps1`
- `docs/LABVIEW_GATING.md`
