# Auto-Release-WhenGreen.ps1

**Path:** `icon-editor-lab-8/tools/Auto-Release-WhenGreen.ps1`  
**Hash:** `0fdf42ef33f4`

## Synopsis
Polls GitHub Actions for a green Pester run on the RC branch and, when green, merges to main and tags vX.Y.Z.

## Description
—



## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
