# New-HostPrepReport.ps1

**Path:** `icon-editor-lab-8/tools/report/New-HostPrepReport.ps1`  
**Hash:** `d1d619e30c85`

## Synopsis
Requires -Version 7.0

## Description
—


### Parameters
| Name | Type | Default |
|---|---|---|
| `Label` | string | ("host-prep-{0}" -f (Get-Date -Format 'yyyyMMddTHHmmss' |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
