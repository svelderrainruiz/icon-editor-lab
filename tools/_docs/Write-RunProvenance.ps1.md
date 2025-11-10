# Write-RunProvenance.ps1

**Path:** `icon-editor-lab-8/tools/Write-RunProvenance.ps1`  
**Hash:** `1214afcc21aa`

## Synopsis
Write run provenance (with fallbacks) to results/provenance.json and optionally append to the job summary.

## Description
Reads GitHub Actions environment variables (and event payload when available) to populate:


### Parameters
| Name | Type | Default |
|---|---|---|
| `ResultsDir` | string | 'tests/results' |
| `FileName` | string | 'provenance.json' |
| `AppendStepSummary` | switch |  |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
