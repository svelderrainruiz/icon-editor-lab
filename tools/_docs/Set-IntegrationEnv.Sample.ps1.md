# Set-IntegrationEnv.Sample.ps1

**Path:** `icon-editor-lab-8/tools/Set-IntegrationEnv.Sample.ps1`  
**Hash:** `2cb7d2a5c7cc`

## Synopsis
Sample script to set environment variables required for CompareVI integration tests.

## Description
Copies or points to existing VI files and sets LV_BASE_VI / LV_HEAD_VI for the current session.


### Parameters
| Name | Type | Default |
|---|---|---|
| `BaseVi` | string | 'C:\Path\To\VI1.vi' |
| `HeadVi` | string | 'C:\Path\To\VI2.vi' |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
