# Reset-IconEditorWorkspace.ps1

**Path:** `tools/icon-editor/Reset-IconEditorWorkspace.ps1`

## Synopsis
Restores the vendor icon-editor LabVIEW project to a known state by running NI’s `RestoreSetupLVSource.ps1`, then optionally closes LabVIEW for each requested version/bitness pair.

## Description
- Resolves the repo + icon-editor roots, confirms the vendor helper scripts exist, and iterates through `-Versions` × `-Bitness`.
- For each combination, runs `RestoreSetupLVSource.ps1 -LabVIEW_Project <name> -Build_Spec <spec>` to reset the workspace, then calls `.github/actions/close-labview/Close_LabVIEW.ps1` unless `-SkipClose` is set.
- Useful in host-prep flows (`Prepare-LabVIEWHost`) to guarantee the development environment matches the fixture expectations.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `RepoRoot` | string | repo root | Icon-editor repo root. |
| `IconEditorRoot` | string | `vendor/icon-editor` | Location of vendor scripts. |
| `Versions` | int[] | `@(2023)` | LabVIEW versions to reset. |
| `Bitness` | int[] | `@(32)` | Bitness list per version. |
| `LabVIEWProject` | string | `lv_icon_editor` | Project passed to restore script. |
| `BuildSpec` | string | `Editor Packed Library` | Build spec used during restore. |
| `SkipClose` | switch | Off | Leave LabVIEW running after restore. |

## Related
- `.github/actions/restore-setup-lv-source/RestoreSetupLVSource.ps1`
- `.github/actions/close-labview/Close_LabVIEW.ps1`
- `tools/icon-editor/Prepare-LabVIEWHost.ps1`
