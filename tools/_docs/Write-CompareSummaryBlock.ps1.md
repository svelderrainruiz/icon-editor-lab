# Write-CompareSummaryBlock.ps1

**Path:** `icon-editor-lab-8/tools/Write-CompareSummaryBlock.ps1`  
**Hash:** `e868a16e9e27`

## Synopsis
Append a concise Compare VI block from compare-summary.json.

## Description
—


### Parameters
| Name | Type | Default |
|---|---|---|
| `Path` | string | 'compare-artifacts/compare-summary.json' |
| `Title` | string | 'Compare VI' |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
