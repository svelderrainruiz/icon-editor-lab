# Write-FixtureDriftSummary.ps1

**Path:** `icon-editor-lab-8/tools/Write-FixtureDriftSummary.ps1`  
**Hash:** `a83c88a01329`

## Synopsis
Append a concise Fixture Drift block from drift-summary.json (best-effort).

## Description
—


### Parameters
| Name | Type | Default |
|---|---|---|
| `Dir` | string | 'results/fixture-drift' |
| `SummaryFile` | string | 'drift-summary.json' |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
