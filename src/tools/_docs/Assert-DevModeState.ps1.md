# Assert-DevModeState.ps1

**Path:** `tools/icon-editor/Assert-DevModeState.ps1`

## Synopsis
Assert that Icon Editor development mode is active (or inactive) for the requested LabVIEW versions/bitness before continuing analyzer or compare stages.

## Description
- Imports `IconEditorDevMode.psm1`, resolves repo/Icon Editor roots, and reads policy defaults via `Get-IconEditorDevModePolicyEntry`.
- Calls `Test-IconEditorDevelopmentMode` for each requested LabVIEW version/bitness (or policy defaults for the current operation).
- Throws with a detailed list of missing/extra targets when the actual dev-mode state does not match `ExpectedActive`, satisfying IELA-SRS-F-001’s “verify before proceeding” clause.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `ExpectedActive` | bool (required) | — | `$true` when you expect dev mode to be on; `$false` after disabling. |
| `RepoRoot` | string | Resolved via `Resolve-IconEditorRepoRoot` | Override when running from a staged bundle. |
| `IconEditorRoot` | string | Derived from repo root | Explicit path to `vendor/icon-editor`. |
| `Versions` | int[] | Policy default | Optional explicit LabVIEW versions. |
| `Bitness` | int[] | Policy default | Optional explicit bitness set. |
| `Operation` | string | `BuildPackage` | Influences policy fallback (e.g., `Compare` defaults to 2025 x64). |

## Exit Codes
- `0` when the state matches expectations
- `!=0` when the assertion fails (terminates with an error)

## Related
- `tools/icon-editor/Enable-DevMode.ps1`
- `tools/icon-editor/Disable-DevMode.ps1`
- `tools/icon-editor/Test-DevModeStability.ps1`
- `docs/LABVIEW_GATING.md`
