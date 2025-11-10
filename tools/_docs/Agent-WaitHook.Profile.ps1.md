# Agent-WaitHook.Profile.ps1

**Path:** `icon-editor-lab-8/tools/Agent-WaitHook.Profile.ps1`  
**Hash:** `dca599cc3869`

## Synopsis
Auto-end wait if marker exists and not yet ended for current startedUtc

## Description
—


### Parameters
| Name | Type | Default |
|---|---|---|
| `Reason` | string | 'unspecified' |
| `ExpectedSeconds` | int | 90 |
| `ToleranceSeconds` | int | 5 |
| `ResultsDir` | string | 'tests/results' |
| `Id` | string | 'default' |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
