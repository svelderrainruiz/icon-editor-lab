# Run-MipLunit-2023x64.ps1

**Path:** `tools/icon-editor/Run-MipLunit-2023x64.ps1`

## Synopsis
Scenario 6a orchestrator: run MissingInProject + VI Analyzer (LabVIEW 2023 x64) and follow up with LUnit tests, emitting an integration summary.

## Description
1. Loads `MipScenarioHelpers.psm1`, verifies required tooling (VI Analyzer Toolkit, g-cli, LabVIEW VI server).  
2. Enforces rogue-LabVIEW preflight (`MIP_EXPECTED_LV_VER=2023`, `MIP_AUTOCLOSE_WRONG_LV=1`).  
3. Runs `Invoke-MissingInProjectSuite.ps1` with `-ViAnalyzerVersion 2023 -ViAnalyzerBitness 64 -RequireCompareReport`.  
4. Locates the resulting `_agent/reports/missing-in-project/<label>.json` and analyzer run directory.  
5. Invokes `.github/actions/run-unit-tests/RunUnitTests.ps1` (LUnit) targeting `vendor/icon-editor/lv_icon_editor.lvproj`.  
6. Writes an integration summary (`tests/results/_agent/reports/integration/<label>.json`, schema `integration/mip-lunit-2023@v1`) capturing toolkit/g-cli checks, analyzer findings, and LUnit totals.

## Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `ProjectPath` | string | `vendor/icon-editor/lv_icon_editor.lvproj` | Project supplied to the LUnit helper. |
| `AnalyzerConfigPath` | string | `configs/vi-analyzer/missing-in-project.viancfg` | Passed to the MissingInProject suite. |
| `ResultsPath` | string | `tests/results` | Root for analyzer/MIP/LUnit artifacts and the integration summary. |
| `AutoCloseWrongLV` | switch | Off | When set, closes non-2023 LabVIEW instances found during preflight. |
| `DryRun` | switch | Off | Logs planned actions without running the suite/LUnit. |

## Exit Codes
- `0` — Analyzer + MissingInProject + LUnit completed successfully.
- `2` — VI Analyzer toolkit missing/broken.
- `3` — MissingInProject suite failed.
- `4` — LUnit failed.

## Related
- `tools/icon-editor/Run-MipLunit-2021x64.ps1`
- `tools/icon-editor/Invoke-MissingInProjectSuite.ps1`
- `docs/LABVIEW_GATING.md`
