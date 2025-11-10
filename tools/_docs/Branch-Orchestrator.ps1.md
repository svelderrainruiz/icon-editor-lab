# Branch-Orchestrator.ps1

**Path:** `icon-editor-lab-8/tools/Branch-Orchestrator.ps1`  
**Hash:** `4fa6708aa88a`

## Synopsis
Requires -Version 7.0

## Description
—


### Parameters
| Name | Type | Default |
|---|---|---|
| `Issue` | int |  |
| `Execute` | switch |  |
| `Base` | string | 'develop' |
| `BranchPrefix` | string | 'issue' |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
