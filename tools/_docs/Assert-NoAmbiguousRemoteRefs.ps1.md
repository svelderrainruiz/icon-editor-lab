# Assert-NoAmbiguousRemoteRefs.ps1

**Path:** `icon-editor-lab-8/tools/Assert-NoAmbiguousRemoteRefs.ps1`  
**Hash:** `1ac82d498a67`

## Synopsis
Ensures the specified remote does not publish multiple refs (branch/tag)

## Description
`git checkout` / `git fetch` operations become ambiguous when a remote



## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
