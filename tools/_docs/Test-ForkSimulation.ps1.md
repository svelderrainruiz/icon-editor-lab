# Test-ForkSimulation.ps1

**Path:** `tools/Test-ForkSimulation.ps1`

## Synopsis
Simulate a fork contributor end-to-end: stage VI changes, open a draft PR from the fork, run all VI Compare workflows (fork auto, staging, history), and optionally clean up.

## Description
- Ensures the working tree is clean, then copies deterministic fixtures under `fixtures/ViAttr` to produce a synthetic change set on a scratch branch (based on `-BaseBranch`, default `develop`).
- Creates/pushes a branch to `origin`, opens a draft PR targeting `upstream/<BaseBranch>`, and records metadata for cleanup.
- Exercises three workflows sequentially:
  1. `vi-compare-fork.yml` (auto-on-PR) — waits for completion via GitHub REST polling.
  2. `pr-vi-staging.yml` — manual dispatch with inputs referencing the new PR.
  3. `pr-vi-history.yml` — manual dispatch verifying multi-commit coverage.
- Each workflow is monitored until `conclusion == success`; failures stop the simulation with details.
- When `-DryRun` is set, prints planned steps without touching git/GitHub. `-KeepBranch` preserves the PR/branch for debugging; otherwise the script closes the PR, deletes the fork branch, and resets the repo to `upstream/<BaseBranch>`.
- Writes results (run URLs/conclusions) to stdout for quick review.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `BaseBranch` | string | `develop` | Upstream branch used for the scratch branch and PR target. |
| `KeepBranch` | switch | Off | Skip cleanup to inspect branch/PR post-run. |
| `DryRun` | switch | Off | Describe actions without mutating git or hitting GitHub. |

## Outputs
- Console summary listing each workflow, conclusion, and run URL.
- Side effect: creates/cleans draft PRs, branches, and workflow runs unless `-DryRun`.

## Exit Codes
- `0` — All workflows completed successfully (or dry run finished without errors).
- Non-zero — Git/GitHub command failures or any workflow concluded with a non-success status.

## Related
- `tools/Test-PRVIStagingSmoke.ps1`
- `tools/Test-PRVIHistorySmoke.ps1`
