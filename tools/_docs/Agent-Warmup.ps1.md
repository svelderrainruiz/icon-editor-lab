# Agent-Warmup.ps1

**Path:** `icon-editor-lab-8/tools/Agent-Warmup.ps1`  
**Hash:** `803b3ffba51c`

## Synopsis
One-stop warm-up command to prep local agent context for #127 (watch telemetry + session lock).

## Description
Sets the LV_* focus-protection toggles and WATCH_RESULTS_DIR.


### Parameters
| Name | Type | Default |
|---|---|---|
| `WatchTestsPath` | string | 'tests/WatchSmoke.Tests.ps1' |
| `SessionLockTestsPath` | string | 'tests/SessionLock.Tests.ps1' |
| `WatchResultsDir` | string |  |
| `SchemaRoot` | string | 'docs/schemas' |
| `SkipSchemaValidation` | switch |  |
| `SkipWatch` | switch |  |
| `SkipSessionLock` | switch |  |
| `SkipRogueScan` | switch |  |
| `SkipAgentWaitValidation` | switch |  |
| `GenerateDashboard` | switch |  |
| `GenerateDashboardHtml` | switch |  |
| `DashboardGroup` | string | 'pester-selfhosted' |
| `DashboardResultsRoot` | string | 'tests/results' |
| `DashboardHtmlPath` | string |  |
| `Quiet` | switch |  |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
