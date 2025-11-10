# Demo-FlakyRecovery.ps1

**Path:** `icon-editor-lab-8/tools/Demo-FlakyRecovery.ps1`  
**Hash:** `057a07f03c72`

## Synopsis
Demonstrate Watch-Pester flaky retry recovery using the Flaky Demo test.

## Description
Ensures the flaky demo state file is reset, enables the demo via environment


### Parameters
| Name | Type | Default |
|---|---|---|
| `DeltaJsonPath` | string | 'tests/results/flaky-demo-delta.json' |
| `RerunFailedAttempts` | int | 2 |
| `Quiet` | switch |  |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
