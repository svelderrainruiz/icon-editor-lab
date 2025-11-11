# Test-PRVIStagingSmoke.ps1

**Path:** `tools/Test-PRVIStagingSmoke.ps1`

## Synopsis
Exercise the `pr-vi-staging.yml` workflow end to end using synthetic VI changes, ensuring the run succeeds and applies the `vi-staging-ready` label.

## Description
- Verifies the working tree is clean and snapshots fixture state before touching `fixtures/` VIs.
- Crafts per-scenario synthetic VI changes (e.g., attribute flips, sequential diffs), pushes scratch branches, and opens draft PRs targeting `upstream/<BaseBranch>`.
- Dispatches `pr-vi-staging.yml` for each scenario, monitors run status via GitHub REST polling, and fails if the workflow conclusion is not `success`.
- Confirms the PR gains the `vi-staging-ready` label and records metadata (branch, PR number, run id, note) into `tests/results/_agent/pr-vi-staging/<scenario>.json`.
- Supports `-DryRun` (no GitHub/git mutation) and `-KeepBranch` (leave PR/branch intact for debugging); default behavior cleans up PRs, removes labels, deletes branches, and restores fixtures/branch state.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `BaseBranch` | string | `develop` | Upstream branch for the synthetic PRs. |
| `KeepBranch` | switch | Off | Skip cleanup of PRs/branches. |
| `DryRun` | switch | Off | Describe actions without executing them. |

## Outputs
- Per-scenario JSON summaries under `tests/results/_agent/pr-vi-staging/`.
- Console logs detailing scenario setup, workflow run IDs, and label verification.

## Exit Codes
- `0` — Workflow(s) succeeded and validations passed (or dry run completed).
- Non-zero — Git/GitHub errors, workflow failures, or label verification issues.

## Related
- `tools/Test-PRVIHistorySmoke.ps1`
- `tools/Test-ForkSimulation.ps1`
