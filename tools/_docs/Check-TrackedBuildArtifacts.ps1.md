# Check-TrackedBuildArtifacts.ps1

**Path:** `icon-editor-lab-8/tools/Check-TrackedBuildArtifacts.ps1`  
**Hash:** `2fa055eaa0f5`

## Synopsis
Fails when tracked build artifacts are present in the repository.

## Description
Scans git-tracked files for common build output locations and test result folders:


### Parameters
| Name | Type | Default |
|---|---|---|
| `AllowPatterns` | string[] |  |
| `AllowListPath` | string | '.ci/build-artifacts-allow.txt' |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
