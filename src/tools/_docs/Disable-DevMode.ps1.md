# Disable-DevMode.ps1

**Path:** `tools/icon-editor/Disable-DevMode.ps1`

## Synopsis
Disable Icon Editor development mode for the specified LabVIEW targets and record the resulting verification payload.

## Description
Mirror image of `Enable-DevMode.ps1`. Resolves repo/icon paths, initializes dev-mode telemetry (`Mode = 'disable'`), and calls `Disable-IconEditorDevelopmentMode`.  
- Records settle events + state file location.  
- Dumps the verification summary so callers can assert dev mode is truly off before running analyzer/compare flows.  
- Telemetry lands under `tests/results/_agent/icon-editor/dev-mode-run/*.json` per IELA-SRS-F-001.


### Parameters
| Name | Type | Default | Notes |
|---|---|---|---|
| `RepoRoot` | string | Resolved via `Resolve-IconEditorRepoRoot` | Repo containing `vendor/icon-editor`. |
| `IconEditorRoot` | string | Derived from repo root | Use to override bundle/extracted paths. |
| `Versions` | int[] | Policy default | LabVIEW versions to disable. |
| `Bitness` | int[] | Policy default | Bitness of LabVIEW targets. |
| `Operation` | string | `BuildPackage` | Label stored in telemetry (Compare, Reliability, etc.). |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` dev mode disabled successfully  
- `!=0` failure (exception text written to telemetry)

## Related
- `tools/icon-editor/Enable-DevMode.ps1`
- `tools/icon-editor/Test-DevModeStability.ps1`
- `docs/LABVIEW_GATING.md`
