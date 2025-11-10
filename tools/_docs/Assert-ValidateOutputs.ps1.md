# Assert-ValidateOutputs.ps1

**Path:** `icon-editor-lab-8/tools/Assert-ValidateOutputs.ps1`  
**Hash:** `3ec2eaca96fb`

## Synopsis
—

## Description
—


### Parameters
| Name | Type | Default |
|---|---|---|
| `ResultsRoot` | string | 'tests/results' |
| `RequireDerivedEnv` | switch | $true |
| `RequireSessionIndex` | switch | $true |
| `RequireFixtureSummary` | switch | $true |
| `RequireDeltaJson` | switch | $false |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
