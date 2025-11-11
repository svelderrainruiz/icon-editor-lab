# Invoke-VIComparisonFromCommit.ps1

**Path:** `tools/icon-editor/Invoke-VIComparisonFromCommit.ps1`

## Synopsis
Clones (or refreshes) the `labview-icon-editor` repo at a specific commit, stages the changed VIs via `Stage-IconEditorSnapshot`, and optionally runs raw VI comparisons against the commit’s parent.

## Description
- Resolves an icon-editor working copy (either a provided `-RepoPath` or `tmp/icon-editor/repo`) using `tools/icon-editor/Sync-IconEditorFork.ps1`, ensuring the requested `-Commit` and branch history are available.
- Produces an overlay of changed files (`tools/icon-editor/Prepare-OverlayFromRepo.ps1`), filters paths with `-IncludePaths` / `-ExcludePaths`, and calls `Stage-IconEditorSnapshot` so downstream validation/LVCompare scripts can act on a self-contained workspace.
- When LVCompare isn’t skipped, fires `tools/Run-HeadlessCompare.ps1` on each VI pair to build `manual-compare/vi-###/captures` folders under the staged snapshot—useful for PR attach artifacts.
- Supports dry runs (planning only), staging name overrides, and manual LabVIEW 2025 resolution (`-LabVIEWExePath`). Environment vars (`LABVIEW_PATH`, `LABVIEWCLI_PATH`, `LVCOMPARE_PATH`) are set for any follow-on steps.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Commit` | string (required) | - | Git commit/ref to stage from the icon-editor repository. |
| `RepoPath` | string | `tmp/icon-editor/repo` | Existing clone to reuse; auto-created otherwise. |
| `RepoSlug` | string | `LabVIEW-Community-CI-CD/labview-icon-editor` | Remote source for sync/clone operations. |
| `Branch` | string | `develop` | Branch to sync before resolving the commit. |
| `WorkspaceRoot` | string | `tests/results/_agent/icon-editor/snapshots` | Parent directory for staged snapshots. |
| `StageName` | string | `commit-<sha8>` | Subfolder name under `WorkspaceRoot`. |
| `SkipSync`, `DryRun` | switch | Off | Skip repo refresh or only print the plan (no staging). |
| `SkipValidate` | switch | Off | Forwarded to `Stage-IconEditorSnapshot` so dev-mode validation can be skipped. |
| `SkipLVCompare` | switch | Off | Prevent the stage helper from running LVCompare on the snapshot. |
| `SkipBootstrapForValidate` | switch | Off | Passes through to avoid reapplying VIPC for local iterations. |
| `IncludePaths` / `ExcludePaths` | string[] | - | Filter the overlay list (repo-relative paths). |
| `HeadlessCompareScript` | string | `tools/Run-HeadlessCompare.ps1` | Custom script for manual comparisons. |
| `LabVIEWExePath` | string | Auto-resolved (2025 x64) | Overrides the LabVIEW binary used for headless compare warmup. |

## Outputs
- Staged snapshot directories under `<WorkspaceRoot>/<StageName>` plus optional `manual-compare/*/captures` results.
- Returns a PSCustomObject describing the commit, files staged, overlay root, and summary from `Stage-IconEditorSnapshot`.
- Writes warnings/errors when VI copies or LVCompare runs fail; CI callers inspect the returned summary to decide whether to continue.

## Exit Codes
- `0` – Snapshot build completed (even if no files required staging).
- `!=0` – Failure to resolve the repo/commit, prepare the overlay, or execute staging/compare helpers.

## Related
- `tools/icon-editor/Prepare-OverlayFromRepo.ps1`
- `tools/icon-editor/Stage-IconEditorSnapshot.ps1`
- `tools/Run-HeadlessCompare.ps1`
