# Auto-Release-WhenGreen.ps1

**Path:** `tools/Auto-Release-WhenGreen.ps1`

## Synopsis
Poll a GitHub Actions workflow for a successful RC branch run; when green, fast-forward merge the RC branch into a target branch and create a release tag.

## Description
- Resolves the repository name from `$env:GITHUB_REPOSITORY` (or `git remote origin`).
- Polls the GitHub API (`/actions/workflows/<workflow>.yml/runs`) every `PollSeconds` seconds until the latest run on `RcBranch` completes successfully or `TimeoutMinutes` expires.
- On success:
  1. `git fetch origin <target>` and `git fetch origin <rc>`.
  2. Checkout the target (`main` by default), fast-forward pull, and merge the RC branch (`git merge --no-ff`).
  3. Push the target branch and create/push an annotated tag (`Tag` parameter).  
- Designed for small release automation where the final merge/tag is triggered once CI is green.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `RcBranch` | string | `release/v0.5.0-rc.1` | Release candidate branch to watch. |
| `WorkflowFile` | string | `test-pester.yml` | Workflow filename monitored for success. |
| `TargetBranch` | string | `main` | Branch to merge into once the workflow is green. |
| `Tag` | string | `v0.5.0` | Annotated tag created after merging. |
| `PollSeconds` | int | `10` | Polling interval for workflow status. |
| `TimeoutMinutes` | int | `10` | Abort after this many minutes if no green run occurs. |

## Exit Codes
- `0` — Merge/tag operations completed.
- `3` — Timed out waiting for a green workflow run.
- Other non-zero values bubble up from git commands or unexpected failures.

## Related
- `tools/After-CommitActions.ps1`
- `tools/Branch-Orchestrator.ps1`
- `docs/ICON_EDITOR_LAB_SRS.md` (release automation)
