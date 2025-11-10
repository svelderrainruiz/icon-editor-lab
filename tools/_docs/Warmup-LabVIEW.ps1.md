# Warmup-LabVIEW.ps1

**Path:** `icon-editor-lab-8/tools/Warmup-LabVIEW.ps1`  
**Hash:** `9334bcc9e2f6`

## Synopsis
Compatibility wrapper for Warmup-LabVIEWRuntime.ps1 (deprecated entry point).

## Description
For backward compatibility, this script forwards to tools/Warmup-LabVIEWRuntime.ps1


### Parameters
| Name | Type | Default |
|---|---|---|
| `LabVIEWPath` | string |  |
| `MinimumSupportedLVVersion` | string |  |
| `SupportedBitness` | string |  |
| `TimeoutSeconds` | int | 30 |
| `IdleWaitSeconds` | int | 2 |
| `JsonLogPath` | string |  |
| `KillOnTimeout` | switch |  |
| `DryRun` | switch |  |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
