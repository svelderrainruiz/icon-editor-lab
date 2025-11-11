# Agent-Warmup.ps1

**Path:** `tools/Agent-Warmup.ps1`

## Synopsis
Preps a self-hosted runner for Icon Editor Lab jobs by exercising watch telemetry, the Session-Lock suite, rogue LV sweeps, and optional dashboard snapshots.

## Description
- Sets focus-protection env toggles (`LV_SUPPRESS_UI`, `LV_NO_ACTIVATE`, etc.) so watch smoke tests and Session-Lock runs do not steal user input.
- `Invoke-WatchSmoke` runs `tests/WatchSmoke.Tests.ps1`, writes telemetry under `_watch/`, and optionally validates both `watch-last.json` and `watch-log.ndjson` against `docs/schemas`.
- `Invoke-SessionLockUnitSuite` executes `tests/SessionLock.Tests.ps1` with the cached Pester configuration to ensure session lock enforcement still works.
- Optional extras:
  - Rogue LV sweep via `tools/Detect-RogueLV.ps1` (skipped with `-SkipRogueScan`).
  - Agent wait validation hook so wait markers are schema-checked.
  - Dashboard JSON / HTML snapshots via `tools/Dev-Dashboard.ps1`.
- Designed to run locally before CI or as a GitHub Actions warmup (`IELA-SRS-F-001` readiness gate). All emitted artifacts land under `tests/results`.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `WatchTestsPath` | string | `tests/WatchSmoke.Tests.ps1` | Entry-point for the watch smoke Pester run. |
| `SessionLockTestsPath` | string | `tests/SessionLock.Tests.ps1` | Exercises the session-lock harness. |
| `WatchResultsDir` | string | `tests/results/_watch` | Destination for watch telemetry (`watch-last.json`, `watch-log.ndjson`). |
| `SchemaRoot` | string | `docs/schemas` | Where schema-lite JSON definitions live. |
| `SkipSchemaValidation` | switch | Off | Set when smoke telemetry should not be validated. |
| `SkipWatch` | switch | Off | Bypass the watch smoke (also disables schema validation unless forced). |
| `SkipSessionLock` | switch | Off | Skip the Session-Lock suite. |
| `SkipRogueScan` | switch | Off | Skip the rogue LabVIEW process sweep. |
| `SkipAgentWaitValidation` | switch | Off | When set, watch telemetry is accepted without cross-checking `_agent/sessions`. |
| `GenerateDashboard` | switch | Off | Capture a JSON dashboard snapshot via `Dev-Dashboard.ps1`. |
| `GenerateDashboardHtml` | switch | Off | When paired with `GenerateDashboard`, also render HTML. |
| `DashboardGroup` | string | `pester-selfhosted` | Dashboard collection id. |
| `DashboardResultsRoot` | string | `tests/results` | Telemetry root for dashboard aggregation and rogue scans. |
| `DashboardHtmlPath` | string | `tests/results/dashboard-warmup.html` | Optional HTML destination (auto-resolved when omitted). |
| `Quiet` | switch | Off | Suppresses `[warmup]` status logs. |

## Outputs
- `tests/results/_watch/watch-last.json` + `watch-log.ndjson`
- `tests/results/_session-lock/session-lock-summary.json`
- `tests/results/_warmup/dashboard-last.json` (+ HTML when requested)
- Rogue-scan report appended to `tests/results/_agent/icon-editor/rogue-watch.json`

## Exit Codes
- `0` when all requested warmup stages pass.
- Non-zero when any smoke, session-lock, or rogue scan failure occurs.

## Related
- `tools/Detect-RogueLV.ps1`
- `tools/Dev-Dashboard.ps1`
- `docs/LABVIEW_GATING.md`
