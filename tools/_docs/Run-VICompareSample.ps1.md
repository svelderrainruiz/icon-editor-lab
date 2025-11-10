# Run-VICompareSample.ps1

**Path:** `icon-editor-lab-8/tools/Run-VICompareSample.ps1`  
**Hash:** `89bd1da9283d`

## Synopsis
Requires -Version 7.0

## Description
—


### Parameters
| Name | Type | Default |
|---|---|---|
| `LabVIEWPath` | string | 'C:\Program Files\National Instruments\LabVIEW 2025\LabVIEW.exe' |
| `BaseVI` | string | 'vendor\icon-editor\.github\actions\missing-in-project\MissingInProject.vi' |
| `HeadVI` | string | 'vendor\icon-editor\.github\actions\missing-in-project\MissingInProjectCLI.vi' |
| `OutputRoot` | string | 'tests/results/teststand-session' |
| `Label` | string | 'vi-compare-smoke' |
| `DryRun` | switch |  |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
