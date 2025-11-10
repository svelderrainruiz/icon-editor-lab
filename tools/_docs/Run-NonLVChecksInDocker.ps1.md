# Run-NonLVChecksInDocker.ps1

**Path:** `icon-editor-lab-8/tools/Run-NonLVChecksInDocker.ps1`  
**Hash:** `27ce3abb4aca`

## Synopsis
Runs non-LabVIEW validation checks (actionlint, markdownlint, docs links, workflow drift)

## Description
Executes the repository's non-LV tooling in containerized environments to mirror CI behaviour



## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
