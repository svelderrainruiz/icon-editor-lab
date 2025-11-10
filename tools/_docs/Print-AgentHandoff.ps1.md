# Print-AgentHandoff.ps1

**Path:** `icon-editor-lab-8/tools/Print-AgentHandoff.ps1`  
**Hash:** `8ea8baf53361`

## Synopsis
—

## Description
—


### Parameters
| Name | Type | Default |
|---|---|---|
| `ApplyToggles` | switch |  |
| `OpenDashboard` | switch |  |
| `AutoTrim` | switch |  |
| `Group` | string | 'pester-selfhosted' |
| `ResultsRoot` | string | (Join-Path (Resolve-Path '.' |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
