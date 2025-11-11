# Generate-ActionOutputsDoc.ps1

**Path:** `tools/Generate-ActionOutputsDoc.ps1`

## Synopsis
Parses `action.yml` and regenerates `docs/action-outputs.md`, documenting the composite action’s inputs/outputs.

## Description
- Requires PowerShell 7 (for `ConvertFrom-Yaml`). Reads `action.yml`, iterates over `inputs` and `outputs`, and writes a Markdown file listing each entry’s description, required flag, and default.
- Defaults:
  - `-ActionPath` → `<repo>/action.yml`
  - `-OutputPath` → `docs/action-outputs.md`
- Creates the destination directory if needed and overwrites the file each run. Safe for both local and CI use, often run as part of release prep before exporting the tooling bundle.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `ActionPath` | string | `action.yml` | Path to the composite action definition. |
| `OutputPath` | string | `docs/action-outputs.md` | Markdown output path. |

## Exit Codes
- `0` on success.
- `1` when `ConvertFrom-Yaml` is unavailable or `action.yml` cannot be read.

## Related
- `docs/action-outputs.md`
- `tools/Export-LabTooling.ps1`
