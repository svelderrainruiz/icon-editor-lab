# Track-WorkflowRun.ps1

**Path:** `tools/Track-WorkflowRun.ps1`

## Synopsis
Stream live status for a GitHub Actions run, optionally persisting the job/check snapshot as JSON.

## Description
- Resolves the repository from `-Repo`, `GITHUB_REPOSITORY`, or `git remote origin`, then polls `gh api repos/{repo}/actions/runs/{RunId}` every `-PollSeconds` seconds.
- Prints a formatted table of each job’s status, conclusion, and duration (suppress via `-Quiet`).
- `-IncludeCheckRuns` queries `repos/{repo}/commits/{sha}/check-runs` so reviewers can see companion checks (code scanning, docs lint, etc.) for the same commit.
- Each poll builds a `workflow-run-snapshot/v1` payload that captures run metadata, jobs, optional check runs, and the capture timestamp.
- `-Json` emits the snapshot to stdout; `-OutputPath` writes UTF-8 JSON to disk (creating parent directories).

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `RunId` | long (required) | — | Actions run identifier from the GitHub UI or `gh run list`. |
| `Repo` | string | Auto | `owner/name`; defaults to `GITHUB_REPOSITORY` or the `origin` remote. |
| `PollSeconds` | int | `15` | Delay between GitHub API calls. |
| `TimeoutSeconds` | int | `1800` | Abort interval; marks the snapshot as `timedOut` and exits 1. |
| `Json` | switch | Off | Write the final snapshot to stdout. |
| `OutputPath` | string | — | File path for the snapshot JSON. |
| `Quiet` | switch | Off | Skip console tables (useful when another tool parses the JSON). |
| `IncludeCheckRuns` | switch | Off | Append GitHub check runs for the run’s head SHA. |

## Outputs
- Console table summarizing jobs (and check runs when requested).
- Snapshot JSON (`workflow-run-snapshot/v1`) written to stdout and/or `-OutputPath`.

## Exit Codes
- `0` — Run completed (or script exited before timeout without errors).
- `1` — Timeout elapsed before completion (snapshot includes `timedOut=true`).
- `>1` — Bubble-up from `gh`/I/O errors.

## Related
- Requires GitHub CLI (`gh`) authentication.
- `tools/Trigger-StandingWorkflow.ps1` (pairs with the standing workflow this monitor often tracks).
