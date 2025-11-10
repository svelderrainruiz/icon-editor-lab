# Diff-FixtureValidationJson.ps1

**Path:** `icon-editor-lab-8/tools/Diff-FixtureValidationJson.ps1`  
**Hash:** `fda176aee731`

## Synopsis
Computes a delta between two fixture validation JSON outputs.

## Description
Compares baseline and current fixture-validation JSON (from Validate-Fixtures.ps1 -Json) and emits a delta JSON with changed counts and newly appearing structural issues.



## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
