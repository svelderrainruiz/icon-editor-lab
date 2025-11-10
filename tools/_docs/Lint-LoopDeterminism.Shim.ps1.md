# Lint-LoopDeterminism.Shim.ps1

**Path:** `icon-editor-lab-8/tools/Lint-LoopDeterminism.Shim.ps1`  
**Hash:** `263352f1d11e`

## Synopsis
Robust wrapper for Lint-LoopDeterminism.ps1 that tolerates mixed/positional args

## Description
—


### Parameters
| Name | Type | Default |
|---|---|---|
| `Paths` | string[] |  |
| `PathsList` | string |  |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
