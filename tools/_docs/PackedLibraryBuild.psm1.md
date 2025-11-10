# PackedLibraryBuild.psm1

**Path:** `icon-editor-lab-8/tools/vendor/PackedLibraryBuild.psm1`  
**Hash:** `ed494fb297ff`

## Synopsis
Helper for orchestrating g-cli packed library builds across bitness targets.

## Description
Executes a build/close/rename cycle for each provided target. Callers supply



## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
