# CompareVI.Tools.psm1

**Path:** `tools/CompareVI.Tools/CompareVI.Tools.psm1`

## Synopsis
PowerShell module that wraps the repo-local CompareVI scripts, exposing friendly functions for history sweeps and ref-to-ref compares.

## Description
- Provides a thin façade over the CLI scripts so external bundles or orchestration pipelines can `Import-Module tools/CompareVI.Tools` and call:
  - `Invoke-CompareVIHistory` → forwards all parameters to `tools/Compare-VIHistory.ps1` after setting `COMPAREVI_SCRIPTS_ROOT` so nested scripts resolve helpers correctly.
  - `Invoke-CompareRefsToTemp` → forwards to `tools/Compare-RefsToTemp.ps1` with the same parameter sets (`ByPath` / `ByName`), keeping command-line parity.
- Internal helper `Get-CompareVIScriptPath` validates the underlying script path before invocation.
- The module itself keeps `Set-StrictMode -Version Latest`, making it safe to import in CI sessions.

### Exported Functions
| Function | Purpose |
| --- | --- |
| `Invoke-CompareVIHistory` | Discovers commit pairs that touched a VI and runs LVCompare against each one (see script doc). |
| `Invoke-CompareRefsToTemp` | Hydrates Base/Head VIs from two refs and runs LVCompare with optional artifact capture. |

## Related
- `tools/CompareVI.Tools/CompareVI.Tools.psd1`
- `tools/Compare-VIHistory.ps1`
- `tools/Compare-RefsToTemp.ps1`
