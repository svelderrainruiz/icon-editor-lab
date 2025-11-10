# Emit-LVClosureCrumb.ps1

**Path:** `icon-editor-lab-8/tools/Emit-LVClosureCrumb.ps1`  
**Hash:** `b8c6fc6bb3bc`

## Synopsis
Emit LV closure telemetry crumbs when enabled.

## Description
When `EMIT_LV_CLOSURE_CRUMBS` is truthy, this script records the current


### Parameters
| Name | Type | Default |
|---|---|---|
| `ResultsDir` | string | 'tests/results' |
| `Phase` | string | 'unknown' |
| `ProcessNames` | string[] | @('LabVIEW' |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
