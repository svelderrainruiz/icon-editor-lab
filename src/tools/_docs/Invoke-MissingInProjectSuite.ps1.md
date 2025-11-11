# Invoke-MissingInProjectSuite.ps1

**Path:** `tools/icon-editor/Invoke-MissingInProjectSuite.ps1`

## Synopsis
Run the MissingInProject Pester suites (compare-only or full dev-mode) with optional VI Analyzer gating, rogue preflight, and report generation.

## Description
- Resolves repo/workspace roots, enforces rogue LabVIEW guardrails (`MIP_EXPECTED_LV_VER`, `MIP_AUTOCLOSE_WRONG_LV`), and mirrors artifacts into `<ResultsPath>/<label>`.
- Runs VI Analyzer first when a `.viancfg` path is provided (parameter or `MIP_VIANALYZER_CONFIG`). Supports automatic dev-mode recovery/retry when analyzer finds broken VIs.
- Invokes `Invoke-PesterTests.ps1` with the selected MissingInProject suite (`compare` or `full`), honouring `-IncludeNegative` or `-SkipNegative`.
- Emits:
  - `_agent/reports/missing-in-project/<label>.json`
  - `<ResultsPath>/<label>/missing-in-project-session.json` (`missing-in-project/run@v1` with analyzer + compare metadata)
  - `latest-run.json`, `run-index.json`, and mirrored compare-report artifacts.
- Implements IELA-SRS-F-008 by ensuring analyzer precedes g-cli and run reports exist per label.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Label` | string | Auto-generated (`mip-<branch>-<sha>-<timestamp>`) | Set explicitly to tie into scenario tracking. |
| `ResultsPath` | string | `tests/results` | Root where run folders + report mirrors are written. |
| `SkipNegative` / `IncludeNegative` | switch | Skip by default | Controls whether negative MissingInProject cases run. |
| `LogPath` | string | — | Optional transcript attached to the run report. |
| `AdditionalPesterArgs` | string[] | — | Forwarded directly to `Invoke-PesterTests.ps1`. |
| `CleanResults` | switch | Off | Removes existing files from `ResultsPath` before running. |
| `RequireCompareReport` | switch | Off | Fails when `compare-report.html` or LVCompare capture is missing; will rerun LVCompare if `MIP_COMPARE_*` env vars are set. |
| `TestSuite` | string (`compare`/`full`) | `compare` | Choose the compare-only suite or the dev-mode suite. |
| `ViAnalyzerConfigPath` | string | — | `.viancfg` path for the analyzer gate (can also come from `MIP_VIANALYZER_CONFIG`). |
| `SkipViAnalyzer` | switch | Off | Bypass the analyzer gate even when a config is present. |
| `ViAnalyzerVersion` | string | `2021` | LabVIEW version used by the analyzer gate. |
| `ViAnalyzerBitness` | int | `64` | LabVIEW bitness for the analyzer gate. |

Environment toggles: `MIP_SKIP_NEGATIVE`, `MIP_LABEL_BRANCH`, `MIP_LABEL_SHA`, `MIP_COMPARE_REPORTS_ROOT`, `MIP_EXPECTED_LV_VER`, `MIP_ROGUE_PREFLIGHT`, `MIP_AUTOCLOSE_WRONG_LV`, `MIP_DEV_MODE_*`.

## Exit Codes
- `0` — Suite passed (reports and session JSON written).
- `!=0` — Analyzer, Pester, or compare failures (message includes the failing stage).

## Related
- `tools/icon-editor/Run-MipLunit-2023x64.ps1`
- `tools/icon-editor/Run-MipLunit-2021x64.ps1`
- `tools/icon-editor/Invoke-VIAnalyzer.ps1`
- `docs/LABVIEW_GATING.md`
