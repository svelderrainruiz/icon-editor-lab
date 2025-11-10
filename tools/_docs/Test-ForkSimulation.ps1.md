# Test-ForkSimulation.ps1

**Path:** `icon-editor-lab-8/tools/Test-ForkSimulation.ps1`  
**Hash:** `8596bb03710a`

## Synopsis
Creates a fork-style pull request, runs the compare workflows, and optionally

## Description
This helper simulates a fork contributor by copying a deterministic VI fixture,


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
