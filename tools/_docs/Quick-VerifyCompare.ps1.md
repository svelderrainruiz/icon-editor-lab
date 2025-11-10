# Quick-VerifyCompare.ps1

**Path:** `icon-editor-lab-8/tools/Quick-VerifyCompare.ps1`  
**Hash:** `f34806afe5ec`

## Synopsis
Quick local verification of Compare VI action outputs (seconds + nanoseconds) without running full Pester.

## Description
Creates temporary placeholder .vi files (unless explicit paths provided), invokes Invoke-CompareVI and

```
./tools/Quick-VerifyCompare.ps1
./tools/Quick-VerifyCompare.ps1 -Same -ShowSummary
./tools/Quick-VerifyCompare.ps1 -Base path\to\A.vi -Head path\to\B.vi
```


### Parameters
| Name | Type | Default |
|---|---|---|
| `Base` | string |  |
| `Head` | string |  |
| `Same` | switch |  |
| `ShowSummary` | switch |  |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
