# Test-PRVIHistorySmoke.ps1

**Path:** `tools/Test-PRVIHistorySmoke.ps1`

## Synopsis
Create a synthetic fork-style PR, dispatch `pr-vi-history.yml`, and verify the workflow completes with the expected comment + artifact output.

## Description
- Ensures git is clean, then crafts synthetic VI history differences (single attribute change or sequential multi-commit scenario via `-Scenario`).
- Pushes a scratch branch to the fork (`origin`), opens a draft PR targeting `upstream/<BaseBranch>`, and dispatches `pr-vi-history.yml` with customized inputs (`max_pairs`, note).
- Polls the workflow run until completion, failing fast if `conclusion != success`.
- Parses the resulting PR comment to confirm comparison/diff counts, downloads the history artifact, and validates `vi-history-summary.json` contents (processed pair count, diffs, target stats).
- Writes a JSON summary to `tests/results/_agent/pr-vi-history-smoke.json` capturing branch, PR number, run ID, scenario metadata, and success flag.
- `-KeepBranch` preserves the PR and branch for debugging; otherwise it closes the PR, deletes local/remote branches, and restores the initial branch.
- `-DryRun` prints planned steps without executing git/GitHub commands.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `BaseBranch` | string | `develop` | Target branch for the smoke PR. |
| `KeepBranch` | switch | Off | Skip cleanup to inspect artifacts manually. |
| `DryRun` | switch | Off | Plan-only mode; no git/GitHub mutations. |
| `Scenario` | string (`attribute`,`sequential`) | `attribute` | Selects the synthetic change pattern. |
| `MaxPairs` | int | `6` | Overrides the workflow’s `max_pairs` input. |

## Outputs
- Console log reporting workflow URLs and validation steps.
- `tests/results/_agent/pr-vi-history-smoke.json` summary.

## Exit Codes
- `0` — Workflow succeeded and validations passed (or dry run completed).
- Non-zero — Git/GitHub failures, workflow errors, or validation mismatches (comment/artifact).

## Related
- `tools/Test-PRVIStagingSmoke.ps1`
- `tools/Test-ForkSimulation.ps1`
