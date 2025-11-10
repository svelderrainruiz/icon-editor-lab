# Write-ArtifactMap.ps1

**Path:** `icon-editor-lab-8/tools/Write-ArtifactMap.ps1`  
**Hash:** `f45cbf9fa0d9`

## Synopsis
Append a detailed artifact map (exists, size, modified) to job summary.

## Description
—


### Parameters
| Name | Type | Default |
|---|---|---|
| `Paths` | string[] |  |
| `PathsList` | string |  |
| `Title` | string | 'Artifacts Map' |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
