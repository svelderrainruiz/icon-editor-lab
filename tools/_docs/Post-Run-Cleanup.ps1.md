# Post-Run-Cleanup.ps1

**Path:** `icon-editor-lab-8/tools/Post-Run-Cleanup.ps1`  
**Hash:** `1aa994904f01`

## Synopsis
Post-run cleanup orchestrator. Aggregates cleanup requests and ensures close

## Description
—


### Parameters
| Name | Type | Default |
|---|---|---|
| `CloseLabVIEW` | switch |  |
| `CloseLVCompare` | switch |  |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
