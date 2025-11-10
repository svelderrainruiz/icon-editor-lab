# Prime-LVCompare.ps1

**Path:** `icon-editor-lab-8/tools/Prime-LVCompare.ps1`  
**Hash:** `cd1ed402ea87`

## Synopsis
Runs LVCompare.exe against two VIs to validate CLI readiness and emit diff breadcrumbs.

## Description
Executes LVCompare.exe with deterministic defaults (-noattr -nofp -nofppos -nobd -nobdcosm), captures


### Parameters
| Name | Type | Default |
|---|---|---|
| `nofppos` |  |  |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
