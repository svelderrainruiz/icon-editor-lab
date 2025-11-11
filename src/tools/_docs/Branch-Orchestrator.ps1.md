# Branch-Orchestrator.ps1

**Path:** `tools/Branch-Orchestrator.ps1`

## Synopsis
Create or switch to an “issue/<number>-<slug>” branch using local snapshots, optionally push to origin and open a PR via `gh`.

## Description
- Accepts an issue number (or infers it from `tests/results/_agent/issue/<n>.json`).
- Builds a branch name using `BranchPrefix` (default `issue`) plus the issue number and slugified snapshot title.
- Ensures the branch exists locally (`git checkout -b <branch> <base>` when needed) after fetching the base (`develop` by default or detected from origin/HEAD).
- When `-Execute` is **not** specified, performs only local branch setup.  
- When `-Execute` is specified:
  - Pushes the branch (`git push -u origin <branch>`).
  - Creates a PR via `gh pr create --fill --base <base> --head <branch>` (if `gh` available).
  - If the snapshot contained a digest, edits the PR body to include the standing priority digest information via `gh pr edit`.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Issue` | int | Derived from `_agent/issue/*.json` | Issue number used for branch naming. |
| `Execute` | switch | Off | Push branch and create PR when set. |
| `Base` | string | `develop` (or origin default) | Base branch for the new branch / PR. |
| `BranchPrefix` | string | `issue` | Prefix used when generating branch names. |

## Exit Codes
- `0` — Branch prepared (and remote operations succeeded when requested).
- `!=0` — Snapshot/issue missing or git operations failed (errors surface to the console).

## Related
- `tools/After-CommitActions.ps1`
- `tools/priority/Run-HandoffTests.ps1`
- `docs/requirements/Icon-Editor-Lab_SRS.md` (issue/branch workflows)
