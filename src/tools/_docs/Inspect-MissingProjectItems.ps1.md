# Inspect-MissingProjectItems.ps1

**Path:** `tools/icon-editor/Inspect-MissingProjectItems.ps1`

## Synopsis
Scans the icon-editor LabVIEW project for missing file references and emits a JSON report listing unresolved URLs.

## Description
- Defaults to `vendor/labview-icon-editor/lv_icon_editor.lvproj` unless `-ProjectPath` overrides it.
- Resolves each `<Item URL="...">` entry (skipping resource/labview.exe entries) to an absolute path; records entries whose files don’t exist.
- Writes a JSON summary (`missing-items.json` under `tests/results/_agent/icon-editor` by default) containing `projectPath`, `generatedAt`, and an array of missing items (`name`, `url`, `resolvedPath`).

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `ProjectPath` | string | `vendor/labview-icon-editor/lv_icon_editor.lvproj` | Project to inspect. |
| `OutputPath` | string | `tests/results/_agent/icon-editor/missing-items.json` | Destination report path. |
| `RepoRoot` | string | auto | Repo root override (used when script runs outside repo root). |

## Exit Codes
- `0` when scan completes (missing files still yield 0).
- Throws when the project file cannot be read.

## Related
- `tools/icon-editor/Invoke-MissingInProjectSuite.ps1`

