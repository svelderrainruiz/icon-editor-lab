# Quick-DispatcherSmoke.ps1

**Path:** `icon-editor-lab-8/tools/Quick-DispatcherSmoke.ps1`  
**Hash:** `b8dd68d05a1d`

## Synopsis
Quick local smoke test for Invoke-PesterTests.ps1.

## Description
Creates a temporary tests folder with a tiny passing test, runs the dispatcher,

```
tools/Quick-DispatcherSmoke.ps1
tools/Quick-DispatcherSmoke.ps1 -Raw -Keep
```



## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
