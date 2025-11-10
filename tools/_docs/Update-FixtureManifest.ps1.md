# Update-FixtureManifest.ps1

**Path:** `icon-editor-lab-8/tools/Update-FixtureManifest.ps1`  
**Hash:** `f81feadb414c`

## Synopsis
Updates fixtures.manifest.json with current SHA256 & size metadata and optional pair digest block.

## Description
Safely updates the manifest used by Validate-Fixtures. Requires explicit -Allow (or -Force).



## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
