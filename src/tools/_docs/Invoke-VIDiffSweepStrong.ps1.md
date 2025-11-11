# Invoke-VIDiffSweepStrong.ps1

**Path:** `tools/icon-editor/Invoke-VIDiffSweepStrong.ps1`

## Synopsis
Runs a “strong” VI diff sweep across an icon-editor repo, reusing cached results, staging snapshots per commit, and emitting telemetry about compare decisions.

## Description
- Wraps `Invoke-VIDiffSweep.ps1` to gather candidate commits/files, then iterates through each commit, staging overlays and running compare flows with options to skip validation/LVCompare or run in dry-run mode.
- Maintains a cache (`icon-editor/vi-diff-cache@v1`) so unchanged commits can be skipped; writes events to `-EventsPath` for auditing.
- Modes:
  - `full` (default) – process every candidate commit according to cache/filters.
  - `quick` – restricts to high-signal commits (logic built into the script).
- Configurable workspace, stage-name prefix, and repo sync control via `-SkipSync`. Accepts `-LabVIEWExePath` for deterministic LV launches.

### Parameters (subset)
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `RepoPath` | string | `tmp/icon-editor/repo` | Repo to scan/stage. |
| `BaseRef` / `HeadRef` | string | *auto* | Range to sweep; defaults mirror `Invoke-VIDiffSweep`. |
| `MaxCommits` | int | `50` | Cap on commits analyzed. |
| `WorkspaceRoot` | string | `tests/results/_agent/icon-editor/sweep` | Where snapshots/captures land. |
| `StageNamePrefix` | string | `commit` | Used when naming per-commit stages. |
| `SkipSync`, `SkipValidate`, `SkipLVCompare`, `DryRun` | switch | Off | Control repo sync and compare behavior. |
| `LabVIEWExePath` | string | - | Explicit LabVIEW path for compare stages. |
| `SummaryPath` | string | - | Optional summary JSON output. |
| `CachePath` | string | `tests/results/_agent/icon-editor/vi-diff-cache.json` | Cache file used to skip unchanged commits. |
| `EventsPath` | string | `tests/results/_agent/icon-editor/vi-diff-events.json` | Event log destination. |
| `Mode` | string (`quick`,`full`) | `full` | Sweep strategy. |
| `Quiet` | switch | Off | Suppress console output. |

## Outputs
- Summary object with per-commit data, cache updates (`vi-diff-cache@v1`), and optional events log.

## Exit Codes
- Non-zero when sync, staging, or compare steps fail (unless suppressed by DryRun).

## Related
- `tools/icon-editor/Invoke-VIDiffSweep.ps1`
- `tools/icon-editor/Stage-IconEditorSnapshot.ps1`
