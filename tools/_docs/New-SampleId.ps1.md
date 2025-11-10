# New-SampleId.ps1

**Path:** `icon-editor-lab-8/tools/New-SampleId.ps1`  
**Hash:** `b4fb138c4117`

## Synopsis
Generate a sample_id for workflow_dispatch runs.

## Description
Emits a compact, readable sample id by default (ts-YYYYMMDD-HHMMSS-XXXX).


### Parameters
| Name | Type | Default |
|---|---|---|
| `Prefix` | string |  |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
