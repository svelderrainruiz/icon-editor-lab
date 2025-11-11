# Follow-OrchestratedRun.ps1

**Path:** `tools/Follow-OrchestratedRun.ps1`

## Synopsis
Uses `gh` to locate the latest `ci-orchestrated` workflow run for the current branch (or a specified one), prints job details, and optionally streams live logs.

## Description
- Determines the target branch from `-Branch` or `git rev-parse --abbrev-ref HEAD`.
- Calls `gh run list --workflow <file|name>` to find the most recent run matching the branch, then displays run metadata (title, SHA, status, URL) and per-job statuses.
- With `-Watch`, executes `gh run watch --exit-status` so logs stream until the run completes; handles authentication failures with helpful warnings.
- Requires GitHub CLI authentication (`gh auth login`) and repository access.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Workflow` | string | `.github/workflows/ci-orchestrated.yml` | Workflow file or name to filter. |
| `Branch` | string | current branch | Override branch used when searching runs. |
| `Watch` | switch | Off | Stream run logs and exit with the run’s conclusion status. |
| `Limit` | int | `15` | Number of recent runs to inspect when matching the branch. |

## Exit Codes
- `0` when run info is printed successfully (and, in watch mode, the run succeeds).
- Non-zero when gh commands fail or, in watch mode, the run ends with a failure/external error.

## Related
- `tools/Dispatch-WithSample.ps1`
- `.github/workflows/ci-orchestrated.yml`
