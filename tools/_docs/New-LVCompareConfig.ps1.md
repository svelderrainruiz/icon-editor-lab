# New-LVCompareConfig.ps1

**Path:** `icon-editor-lab-8/tools/New-LVCompareConfig.ps1`  
**Hash:** `06b48b436b24`

## Synopsis
Requires -Version 7.0

## Description
—


### Parameters
| Name | Type | Default |
|---|---|---|
| `OutputPath` | string |  |
| `NonInteractive` | switch |  |
| `Force` | switch |  |
| `Probe` | switch |  |
| `LabVIEWExePath` | string |  |
| `LVComparePath` | string |  |
| `LabVIEWCLIPath` | string |  |
| `Version` | string |  |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
