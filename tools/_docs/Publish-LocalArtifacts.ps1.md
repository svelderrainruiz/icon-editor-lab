# Publish-LocalArtifacts.ps1

**Path:** `icon-editor-lab-8/tools/icon-editor/Publish-LocalArtifacts.ps1`  
**Hash:** `99a8242fce21`

## Synopsis
Requires -Version 7.0

## Description
—


### Parameters
| Name | Type | Default |
|---|---|---|
| `ArtifactsRoot` | string | 'tests/results/_agent/icon-editor' |
| `GhTokenPath` | string |  |
| `ReleaseTag` | string |  |
| `ReleaseName` | string |  |
| `SkipUpload` | switch |  |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
