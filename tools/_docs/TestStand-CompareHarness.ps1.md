# TestStand-CompareHarness.ps1

**Path:** `icon-editor-lab-8/tools/TestStand-CompareHarness.ps1`  
**Hash:** `034ed9ea18b7`

## Synopsis
Thin wrapper for TestStand: warmup LabVIEW runtime, run LVCompare, and optionally close.

## Description
Sequentially invokes Warmup-LabVIEWRuntime.ps1 (to ensure LabVIEW readiness), then



## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
