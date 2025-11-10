# Write-SessionIndexSummary.ps1

**Path:** `icon-editor-lab-8/tools/Write-SessionIndexSummary.ps1`  
**Hash:** `d7fc7d9b8bc5`

## Synopsis
Append a concise Session block from tests/results/session-index.json.

## Description
—


### Parameters
| Name | Type | Default |
|---|---|---|
| `ResultsDir` | string | 'tests/results' |
| `FileName` | string | 'session-index.json' |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
