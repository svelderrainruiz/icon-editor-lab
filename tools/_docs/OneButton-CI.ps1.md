# OneButton-CI.ps1

**Path:** `icon-editor-lab-8/tools/OneButton-CI.ps1`  
**Hash:** `e21f85ee9951`

## Synopsis
One-button end-to-end CI trigger and artifact post-processing for #127.

## Description
Dispatches Validate and CI Orchestrated (strategy=single, include_integration=true)


### Parameters
| Name | Type | Default |
|---|---|---|
| `Ref` | string |  |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
