# After-CommitActions.ps1

**Path:** `tools/After-CommitActions.ps1`

## Synopsis
Lightweight helper that runs post-commit automation: push the current branch and optionally open a PR via `gh`, while logging a JSON summary under `_agent/post-commit.json`.

## Description
- Resolves the repository root (defaults to `.`) and ensures `tests/results/_agent` exists.
- Captures shell output/exit codes from `git` commands via `Invoke-Git`.
- When `-Push` is supplied, runs `git push -u origin <branch>` and records the exit code/output in `post-commit.json`.
- When `-CreatePR` is supplied and the GitHub CLI (`gh`) is available, runs `gh pr create --fill --base develop` and records the result; otherwise notes that `gh` is missing.
- Writes `tests/results/_agent/post-commit.json` (`post-commit/actions@v1`) with fields such as `branch`, `pushExecuted`, `pushResult`, and `prResult`.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `RepositoryRoot` | string | `.` | Root of the repo where git commands are run. |
| `Push` | switch | Off | Push the current branch to `origin`. |
| `CreatePR` | switch | Off | Create a PR via `gh pr create` (requires GH CLI). |

## Exit Codes
- `0` — Summary written (even if push/PR failed; see JSON for details).
- `!=0` — Only thrown if the script itself encounters an unexpected error (e.g., repo not found).

## Related
- `tools/Auto-Release-WhenGreen.ps1`
- `tools/Branch-Orchestrator.ps1`
- `docs/requirements/Icon-Editor-Lab_SRS.md` (release requirements)
