# Capture-LabVIEWSnapshot.ps1

**Path:** `icon-editor-lab-8/tools/Capture-LabVIEWSnapshot.ps1`  
**Hash:** `5813d10631d6`

## Synopsis
Capture a snapshot of active LabVIEW.exe processes for diagnostics.

## Description
Enumerates LabVIEW.exe processes (if any) and writes a JSON report capturing


### Parameters
| Name | Type | Default |
|---|---|---|
| `OutputPath` | string | 'tests/results/_warmup/labview-processes.json' |
| `Quiet` | switch |  |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
