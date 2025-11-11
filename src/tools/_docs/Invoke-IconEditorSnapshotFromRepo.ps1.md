# Invoke-IconEditorSnapshotFromRepo.ps1

**Path:** `tools/icon-editor/Invoke-IconEditorSnapshotFromRepo.ps1`

## Synopsis
Prepares an overlay of icon-editor resource/test VI changes between refs and stages a snapshot using `Stage-IconEditorSnapshot.ps1`.

## Description
- Calls `Prepare-OverlayFromRepo.ps1` to detect resource/test VI changes between `-BaseRef` and `-HeadRef` within a vendor repo (`-RepoPath`).
- If no changes are detected, returns early with `stageExecuted=false`. Otherwise, invokes `Stage-IconEditorSnapshot.ps1` to apply overlays, validate, and capture fixtures.
- Supports workspace/customization options: `-WorkspaceRoot`, `-StageName`, `-OverlayRoot`, `-FixturePath`, `-BaselineFixture`, `-BaselineManifest`.
- Flags like `-SkipValidate`, `-SkipLVCompare`, `-DryRun`, and `-SkipBootstrapForValidate` are forwarded to the staging script.
- Returns a PSCustomObject containing overlay details, file list, and stage summary metadata.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `RepoPath` | string (required) | - | Icon editor repo containing resource/Test VIs. |
| `BaseRef` | string | *none* | Starting git ref used for overlay detection. |
| `HeadRef` | string | `HEAD` | Ending git ref. |
| `StageName` | string | timestamp | Name for the staged snapshot folder. |
| `WorkspaceRoot` | string | `tests/results/_agent/icon-editor/snapshots` | Root where snapshots live. |
| `OverlayRoot` | string | `<WorkspaceRoot>/_overlay` | Temp overlay directory. |
| `FixturePath` | string (required) | VIP produced by the build. |
| `BaselineFixture`, `BaselineManifest` | string | - | Optional baseline fixtures/manifests. |
| `SkipValidate`, `SkipLVCompare`, `DryRun`, `SkipBootstrapForValidate` | switch | Off | Control staging validation behavior. |

## Outputs
- PSCustomObject with overlay path, changed files, stage root, and the summary returned by `Stage-IconEditorSnapshot.ps1`.

## Exit Codes
- Non-zero when prerequisites or staging scripts fail.

## Related
- `tools/icon-editor/Prepare-OverlayFromRepo.ps1`
- `tools/icon-editor/Stage-IconEditorSnapshot.ps1`
