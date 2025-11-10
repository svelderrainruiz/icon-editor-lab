# Lint-LoopDeterminism.ps1

**Path:** `icon-editor-lab-8/tools/Lint-LoopDeterminism.ps1`  
**Hash:** `c00913127919`

## Synopsis
Lint for CI loop determinism patterns in workflow/script content.

## Description
Scans YAML/PS files for loop-related knobs and flags common non-deterministic patterns



## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
