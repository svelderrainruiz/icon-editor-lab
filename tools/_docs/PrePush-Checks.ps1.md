# PrePush-Checks.ps1

**Path:** `icon-editor-lab-8/tools/PrePush-Checks.ps1`  
**Hash:** `1b1d3910603f`

## Synopsis
Local pre-push checks: run actionlint against workflows.

## Description
Ensures a valid actionlint binary is used per-OS and runs it against .github/workflows.



## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
