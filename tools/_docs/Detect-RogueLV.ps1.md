# Detect-RogueLV.ps1

**Path:** `icon-editor-lab-8/tools/Detect-RogueLV.ps1`  
**Hash:** `3a6070853472`

## Synopsis
—

## Description
—


### Parameters
| Name | Type | Default |
|---|---|---|
| `ResultsDir` | string | 'tests/results' |
| `LookBackSeconds` | int | 900 |
| `FailOnRogue` | switch |  |
| `AppendToStepSummary` | switch |  |
| `Quiet` | switch |  |
| `RetryCount` | int | 1 |
| `RetryDelaySeconds` | int | 5 |
| `OutputPath` | string |  |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
