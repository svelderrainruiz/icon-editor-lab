# Write-AgentContext.ps1

**Path:** `icon-editor-lab-8/tools/Write-AgentContext.ps1`  
**Hash:** `c9132d0cd4a0`

## Synopsis
Repo context

## Description
—


### Parameters
| Name | Type | Default |
|---|---|---|
| `ResultsDir` | string | 'tests/results' |
| `MaxNotices` | int | 10 |
| `AppendToStepSummary` | switch |  |
| `Quiet` | switch |  |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
