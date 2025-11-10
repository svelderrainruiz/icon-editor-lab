# Check-PRMergeable.ps1

**Path:** `icon-editor-lab-8/tools/Check-PRMergeable.ps1`  
**Hash:** `7f2ca7dea993`

## Synopsis
Check a pull request mergeability state via the GitHub API.

## Description
Calls the GitHub REST API to retrieve merge status for the specified pull request

```
pwsh -File tools/Check-PRMergeable.ps1 -Number 274 -FailOnConflict
```



## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
