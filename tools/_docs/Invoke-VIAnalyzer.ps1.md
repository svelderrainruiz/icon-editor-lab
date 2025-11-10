# Invoke-VIAnalyzer.ps1

**Path:** `icon-editor-lab-8/tools/icon-editor/Invoke-VIAnalyzer.ps1`  
**Hash:** `e934bb6a6b4f`

## Synopsis
Runs the LabVIEW VI Analyzer headlessly via LabVIEWCLI and captures telemetry.

## Description
Wraps the `RunVIAnalyzer` LabVIEWCLI operation so CI helpers can invoke VI



## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
