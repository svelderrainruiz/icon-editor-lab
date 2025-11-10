# Write-PesterTopFailures.ps1

**Path:** `icon-editor-lab-8/tools/Write-PesterTopFailures.ps1`  
**Hash:** `da21dbe044da`

## Synopsis
Append a concise “Top Failures” section to the job summary from Pester outputs.

## Description
—


### Parameters
| Name | Type | Default |
|---|---|---|
| `ResultsDir` | string | 'tests/results' |
| `Top` | int | 5 |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
