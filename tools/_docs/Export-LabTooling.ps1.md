# Export-LabTooling.ps1

**Path:** `icon-editor-lab-8/tools/Export-LabTooling.ps1`  
**Hash:** `cbb37b519c2f`

## Synopsis
Requires -Version 7.0

## Description
—


### Parameters
| Name | Type | Default |
|---|---|---|
| `Destination` | string | 'artifacts/icon-editor-lab-tooling.zip' |
| `IncludePaths` | string[] | @(
    'tools' |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
