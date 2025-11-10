# Prepare-OverlayFromRepo.ps1

**Path:** `icon-editor-lab-8/tools/icon-editor/Prepare-OverlayFromRepo.ps1`  
**Hash:** `9d4a7037b39d`

## Synopsis
Requires -Version 7.0

## Description
—


### Parameters
| Name | Type | Default |
|---|---|---|
| `RepoPath` | string |  |
| `BaseRef` | string |  |
| `HeadRef` | string | 'HEAD' |
| `OverlayRoot` | string |  |
| `IncludePatterns` | string[] | @('resource/' |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
