# Enable-DevMode.ps1

**Path:** `tools/icon-editor/Enable-DevMode.ps1`

## Synopsis
Enable Icon Editor development mode for one or more LabVIEW targets, emitting telemetry and verifying the resulting token state.

## Description
Wrapper around `Enable-IconEditorDevelopmentMode` that resolves repo/icon-editor roots, enforces rogue-process preflight, and records telemetry via `Initialize-IconEditorDevModeTelemetry`.  
Stages:
1. Resolve `RepoRoot`/`IconEditorRoot`, import `IconEditorDevMode.psm1`.  
2. Run `Invoke-IconEditorRogueCheck -FailOnRogue -AutoClose` so non-matching LabVIEW instances are closed before toggling dev mode.  
3. Execute the dev-mode enable call; capture the returned state path, `UpdatedAt`, and verification payload.  
4. Persist settle events/telemetry (`tests/results/_agent/icon-editor/dev-mode-run/*.json`) to satisfy IELA-SRS-F-001.


### Parameters
| Name | Type | Default | Notes |
|---|---|---|---|
| `RepoRoot` | string | Resolved via `Resolve-IconEditorRepoRoot` | Optional explicit repo root. |
| `IconEditorRoot` | string | Derived from repo root | Path to `vendor/icon-editor`. |
| `Versions` | int[] | Policy-driven default | LabVIEW versions to toggle (e.g., `@(2023,2025)`). |
| `Bitness` | int[] | Policy-driven default | Target bitness (`@(64)` by default). |
| `Operation` | string | `BuildPackage` | Label recorded in telemetry (Compare, Reliability, etc.). |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` dev mode enabled successfully  
- `!=0` failure (telemetry captures exception text)

## Related
- `tools/icon-editor/Disable-DevMode.ps1`
- `tools/icon-editor/Test-DevModeStability.ps1`
- `docs/LABVIEW_GATING.md`
