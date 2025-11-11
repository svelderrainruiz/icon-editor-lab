# MipScenarioHelpers.psm1

**Path:** `tools/icon-editor/MipScenarioHelpers.psm1`

## Synopsis
Utility module consumed by MissingInProject + MipLunit scenarios (6a/6b) to resolve paths, confirm tooling prerequisites, and format telemetry.

## Description
Exports helper functions such as:
- `Resolve-Abs` — Normalize relative/absolute paths for project/config inputs.
- `Test-VIAnalyzerToolkit` — Ensure the VI Analyzer Toolkit is installed for the requested version/bitness; returns reason/toolkit path.
- `Test-GCliAvailable` — Locate g-cli (version info + availability).
- `Get-LabVIEWServerInfo` — Inspect `LabVIEW.ini` for VI Server enablement/port settings.
- `Initialize-IntegrationSummary` / `Save-IntegrationSummary` (see script body) — Build and persist `_agent/reports/integration/*.json` for the MipLunit flows.

These helpers centralize the preflight checks used by `Run-MipLunit-2023x64.ps1` and `Run-MipLunit-2021x64.ps1`.

### Functions
| Function | Purpose |
| --- | --- |
| `Resolve-Abs` | Return an absolute path from a candidate + base path. |
| `Test-VIAnalyzerToolkit` | Verify that LabVIEW + VI Analyzer Toolkit exist; returns `{ exists, reason, toolkitPath, labviewExe }`. |
| `Test-GCliAvailable` | Check whether `g-cli` is on PATH and capture its version string. |
| `Get-LabVIEWServerInfo` | Read VI server settings (enabled flag, port, warnings). |
| `Initialize-IntegrationSummary` | Create the ordered summary object saved by the scenario scripts. |
| `Save-IntegrationSummary` | Flush summary JSON to disk with updated timestamps/status. |

## Related
- `tools/icon-editor/Run-MipLunit-2023x64.ps1`
- `tools/icon-editor/Run-MipLunit-2021x64.ps1`
- `tools/icon-editor/Invoke-MissingInProjectSuite.ps1`
