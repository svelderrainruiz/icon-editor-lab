# Sync-IconEditorFork.ps1

**Path:** `tools/icon-editor/Sync-IconEditorFork.ps1`

## Synopsis
Clones the upstream icon-editor repository (or a custom slug) to `vendor/labview-icon-editor` or a specified working path, with optional fixture updates and local Validate runs.

## Description
- Resolves the Git remote (`RemoteName` default `icon-editor`). If the remote isn’t configured, `-RepoSlug` (`owner/repo`) is required.
- Clones the requested branch into `tmp/icon-editor-sync`, mirrors it onto the target path (default `vendor/labview-icon-editor`), and removes the temp clone.
- Optional flags:
  - `-UpdateFixture` runs `tools/icon-editor/Update-IconEditorFixtureReport.ps1`.
  - `-RunValidateLocal` invokes `tools/icon-editor/Invoke-ValidateLocal.ps1` (supports `-SkipBootstrap`).
- `-WorkingPath` lets you mirror into a custom directory (fixture/validate helpers are disabled in that mode).

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `RemoteName` | string | `icon-editor` |
| `RepoSlug` | string | - | `owner/repo` when the remote isn’t configured. |
| `Branch` | string | `develop` |
| `WorkingPath` | string | `vendor/labview-icon-editor` |
| `UpdateFixture` | switch | Off | Runs fixture report/manifest updates. |
| `RunValidateLocal` | switch | Off | Runs local Validate pipeline (requires vendor path). |
| `SkipBootstrap` | switch | Off | Passed through to Validate helper. |

## Outputs
- Synchronizes the vendor folder, prints a summary, and returns a PSCustomObject describing the remote, branch, and mirror path.

## Related
- `vendor/labview-icon-editor`
- `tools/icon-editor/Update-IconEditorFixtureReport.ps1`

