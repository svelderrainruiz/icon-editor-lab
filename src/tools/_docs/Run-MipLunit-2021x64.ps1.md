# Run-MipLunit-2021x64.ps1

**Path:** `tools/icon-editor/Run-MipLunit-2021x64.ps1`

## Synopsis
Scenario 6b orchestrator: run the legacy MissingInProject + LUnit lane using LabVIEW 2021 x64 with analyzer gating and integration reporting.

## Description
- Mirrors the 2023 flow but forces legacy toggles (`MIP_ALLOW_LEGACY=1`, LabVIEW 2021 paths, analyzer bitness 64).  
- Performs rogue-LabVIEW preflight, runs `Invoke-MissingInProjectSuite.ps1` with 2021 settings, then executes `.github/actions/run-unit-tests/RunUnitTests.ps1` targeting the Icon Editor project.  
- Captures results in `tests/results/_agent/reports/integration/<label>.json` (`integration/mip-lunit-2021@v1`) along with analyzer logs and LUnit totals.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `ProjectPath` | string | `vendor/icon-editor/lv_icon_editor.lvproj` | Project file for the LUnit helper. |
| `AnalyzerConfigPath` | string | `configs/vi-analyzer/missing-in-project.viancfg` | Passed to the analyzer gate. |
| `ResultsPath` | string | `tests/results` | Root for analyzer/LUnit artifacts and integration summaries. |
| `AutoCloseWrongLV` | switch | Off | Close non-2021 LabVIEW instances when rogue preflight runs. |
| `DryRun` | switch | Off | Print planned steps without invoking MissingInProject or LUnit. |

## Exit Codes
- `0` — Analyzer + MissingInProject + LUnit succeeded.
- `2` — VI Analyzer toolkit missing/broken.
- `3` — MissingInProject suite failed.
- `4` — LUnit failed.

## Related
- `tools/icon-editor/Run-MipLunit-2023x64.ps1`
- `tools/icon-editor/Invoke-MissingInProjectSuite.ps1`
- `docs/LABVIEW_GATING.md`
