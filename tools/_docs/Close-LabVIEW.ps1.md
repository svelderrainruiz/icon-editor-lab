# Close-LabVIEW.ps1

**Path:** `icon-editor-lab-8/tools/Close-LabVIEW.ps1`  
**Hash:** `9ca1649fffc7`

## Synopsis
Gracefully closes a running LabVIEW instance using the provider-agnostic CLI abstraction.

## Description
Routes the CloseLabVIEW operation through tools/LabVIEWCli.psm1, which selects an available provider


### Parameters
| Name | Type | Default |
|---|---|---|
| `LabVIEWExePath` | string |  |
| `MinimumSupportedLVVersion` | string |  |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
