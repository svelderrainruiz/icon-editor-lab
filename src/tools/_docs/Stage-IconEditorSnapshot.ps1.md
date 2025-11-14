# Stage-IconEditorSnapshot.ps1

**Path:** `tools/icon-editor/Stage-IconEditorSnapshot.ps1`

## Synopsis
Stage a self-contained Icon Editor snapshot (source + overlay + fixture metadata), optionally run validation, and emit `session-index.json` for downstream compare/analyze flows.

## Description
- Resolves repo root, icon-editor source, workspace, fixture and overlay paths.
- Copies the icon-editor tree into `<WorkspaceRoot>/<StageName>`, writes:
  - `head-manifest.json` / `fixture-report.json` via `Update-IconEditorFixtureReport.ps1`
  - `missing-in-project` validation artifacts if `-SkipValidate` is omitted (`Invoke-ValidateLocal.ps1` by default)
  - `<stageRoot>/session-index.json` (`icon-editor/snapshot-session@v1`) summarizing source, overlays, validation, and dev-mode selections.
- Optionally toggles dev mode (using `DevModeVersions/Bitness` + policy) before validation and disables it afterward.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `SourcePath` | string | `vendor/labview-icon-editor` | Root to stage (bundle/import). |
| `WorkspaceRoot` | string | `tests/results/_agent/icon-editor/snapshots` | Parent directory for staged snapshots. |
| `StageName` | string | `snapshot-{timestamp}` | Folder name under the workspace. |
| `FixturePath` | string | — (required) | VIP/fixture to include in the manifest/report. |
| `ResourceOverlayRoot` | string | `<SourcePath>/resource` | Additional files layered into the snapshot. |
| `BaselineFixture` / `BaselineManifest` | string | env overrides | Used when comparing fixtures during validation. |
| `InvokeValidateScript` | string | `tools/icon-editor/Invoke-ValidateLocal.ps1` | Allows substituting another validator. |
| `SkipValidate` / `SkipLVCompare` / `DryRun` | switch | Off | Controls validation behavior. |
| `DevModeVersions` / `DevModeBitness` | int[] | `@(2025)` / `@(64)` | Passed to `Enable-IconEditorDevelopmentMode`. |
| `DevModeOperation` | string | `Compare` | Label for dev-mode telemetry. |
| `SkipDevMode` | switch | Off | Prevents dev-mode toggling entirely. |

## Exit Codes
- `0` snapshot created successfully
- `!=0` validation/dev-mode failures (exceptions bubble up)

## Related
- `tools/icon-editor/Invoke-ValidateLocal.ps1`
- `tools/icon-editor/Enable-DevMode.ps1`
- `tools/icon-editor/Invoke-MissingInProjectSuite.ps1`
- `tools/README.md`

