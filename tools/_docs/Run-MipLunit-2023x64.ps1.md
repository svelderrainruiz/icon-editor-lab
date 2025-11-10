# Run-MipLunit-2023x64.ps1

**Path:** `icon-editor-lab-8/tools/icon-editor/Run-MipLunit-2023x64.ps1`  
**Hash:** `5a898db254bf`

## Synopsis
Orchestrates Scenario 6a (MIP 2023 x64 + LUnit) end-to-end.

## Description
Runs a guarded MissingInProject suite with the VI Analyzer gate targeting LabVIEW 2023 x64,


### Parameters
| Name | Type | Default |
|---|---|---|
| `ProjectPath` | string | 'vendor/icon-editor/lv_icon_editor.lvproj' |
| `AnalyzerConfigPath` | string | 'configs/vi-analyzer/missing-in-project.viancfg' |
| `ResultsPath` | string | 'tests/results' |
| `AutoCloseWrongLV` | switch |  |
| `DryRun` | switch |  |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
