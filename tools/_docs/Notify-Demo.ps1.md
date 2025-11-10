# Notify-Demo.ps1

**Path:** `icon-editor-lab-8/tools/Notify-Demo.ps1`  
**Hash:** `faa8d2009e27`

## Synopsis
Simple demo notify script. Writes a concise line plus environment reflection.

## Description
—


### Parameters
| Name | Type | Default |
|---|---|---|
| `Status` | string |  |
| `Failed` | int |  |
| `Tests` | int |  |
| `Skipped` | int |  |
| `RunSequence` | int |  |
| `Classification` | string |  |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
