# Warmup-LabVIEWRuntime.ps1

**Path:** `icon-editor-lab-8/tools/Warmup-LabVIEWRuntime.ps1`  
**Hash:** `e514d7c531db`

## Synopsis
Deterministic LabVIEW runtime warmup for self-hosted Windows runners.

## Description
Ensures a LabVIEW.exe process is running (or can be started) before downstream


### Parameters
| Name | Type | Default |
|---|---|---|
| `StopAfterWarmup` |  |  |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
