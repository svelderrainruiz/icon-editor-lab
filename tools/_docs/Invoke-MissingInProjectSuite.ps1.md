# Invoke-MissingInProjectSuite.ps1

**Path:** `icon-editor-lab-8/tools/icon-editor/Invoke-MissingInProjectSuite.ps1`  
**Hash:** `74ecff3cc42d`

## Synopsis
Runs the MissingInProject Pester suite end-to-end with optional VI Analyzer gating.

## Description
Invokes `Invoke-PesterTests.ps1` against either the compare-only or full



## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
