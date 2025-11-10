# Close-LVCompare.ps1

**Path:** `icon-editor-lab-8/tools/Close-LVCompare.ps1`  
**Hash:** `251463f9dda3`

## Synopsis
Runs LVCompare.exe against a pair of VIs using an explicit LabVIEW executable path (default: LabVIEW 2025 64-bit) and ensures the compare process exits.

## Description
Mirrors the environment-first pattern used by Close-LabVIEW.ps1. The script resolves the LVCompare



## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
