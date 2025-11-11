# Export-LabTooling.ps1

**Path:** `tools/Export-LabTooling.ps1`

## Synopsis
Packages the current lab tooling (scripts, configs, vendor bundle, docs) into `artifacts/icon-editor-lab-tooling.zip` for downstream consumption.

## Description
- Copies the paths listed in `-IncludePaths` (defaults to `tools`, `configs`, `vendor`, and key docs) into a temp staging directory.
- Creates the destination zip at `-Destination` (`artifacts/icon-editor-lab-tooling.zip` by default), creating parent directories as needed.
- Skips missing include paths with a warning; use `-Force` to overwrite an existing zip.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Destination` | string | `artifacts/icon-editor-lab-tooling.zip` | Target zip path (relative or absolute). |
| `IncludePaths` | string[] | `tools`, `configs`, `vendor`, docs | Paths copied into the archive. |
| `Force` | switch | Off | Overwrite `Destination` if it already exists. |

## Outputs
- Creates/updates the zip archive referenced by `-Destination`.

## Exit Codes
- `0` on success.
- Non-zero when staging or compression fails (e.g., invalid paths, locked files).

## Related
- `tools/Get-IconEditorLabTooling.ps1`
- `docs/LABVIEW_GATING.md`
