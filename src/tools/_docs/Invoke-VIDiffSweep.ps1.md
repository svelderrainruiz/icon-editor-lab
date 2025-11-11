# Invoke-VIDiffSweep.ps1

**Path:** `tools/icon-editor/Invoke-VIDiffSweep.ps1`

## Synopsis
Synchronizes (or reuses) an icon-editor repo, finds VI comparison candidates, and writes the manifest to `tests/results/_agent/icon-editor/vi-changes.json`.

## Description
- Runs `tools/compare/Find-VIComparisonCandidates.ps1` against `-RepoPath` (default `tmp/icon-editor/repo`, auto-synced via `Sync-IconEditorFork.ps1` unless `-SkipSync`).
- Resolves compare range from `-BaseRef`/`-HeadRef` or defaults to the latest `origin/<Branch>` plus `MaxCommits`.
- Accepts filtering (`Kinds`, `IncludePatterns`, `Extensions`) and prints a summary (`SummaryCount` top commits) unless `-Quiet` is set.
- Returns a PSCustomObject with the candidates object and output path.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `RepoPath` | string | `tmp/icon-editor/repo` | Repo scanned for VI changes; auto-synced when missing. |
| `RepoSlug` | string | `LabVIEW-Community-CI-CD/labview-icon-editor` | GitHub slug for sync helper. |
| `Branch` | string | `develop` | Branch to sync/compare against. |
| `BaseRef` / `HeadRef` | string | derived | Compare range bounds (auto when omitted). |
| `MaxCommits` | int | `50` | Max commits to scan. |
| `Kinds`, `IncludePatterns`, `Extensions` | string[] | defaults from Find-VIComparisonCandidates | Filter candidates. |
| `OutputPath` | string | `tests/results/_agent/icon-editor/vi-changes.json` | Manifest destination. |
| `SummaryCount` | int | `10` | Number of entries shown in the console summary. |
| `SkipSync` | switch | Off | Skip repo sync even if missing. |
| `Quiet` | switch | Off | Suppress console summary. |

## Outputs
- JSON manifest (via `Find-VIComparisonCandidates`) describing VI diffs. The command also prints summary lines when not quiet.

## Exit Codes
- Non-zero when repo sync, git validation, or candidate generation fails.

## Related
- `tools/compare/Find-VIComparisonCandidates.ps1`
- `tools/icon-editor/Sync-IconEditorFork.ps1`
