# Test-PRVIHistorySmoke.ps1

**Path:** `icon-editor-lab-8/tools/Test-PRVIHistorySmoke.ps1`  
**Hash:** `1f4b2ba6ad29`

## Synopsis
End-to-end smoke test for the PR VI history workflow.

## Description
Creates a disposable branch with a synthetic VI change, opens a draft PR,


### Parameters
| Name | Type | Default |
|---|---|---|
| `BaseBranch` | string | 'develop' |
| `KeepBranch` | switch |  |
| `DryRun` | switch |  |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
