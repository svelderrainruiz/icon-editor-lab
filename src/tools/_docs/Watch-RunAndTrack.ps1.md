# Watch-RunAndTrack.ps1

**Path:** `tools/Watch-RunAndTrack.ps1`

## Synopsis
Triggers a GitHub Actions workflow (`gh workflow run`) and then monitors the new run via `Track-WorkflowRun.ps1` until completion, optionally saving job telemetry.

## Description
- Dispatches the chosen workflow (`-Workflow`, default `validate.yml`) against the specified repo/ref (infers repo from `GITHUB_REPOSITORY` or git remote, and ref from the current branch when absent).
- Polls `gh run list` to find the newly dispatched run (with `-PollSeconds` / `-TimeoutSeconds` guard), then calls `tools/Track-WorkflowRun.ps1` to stream job-level updates.
- `-OutputPath` stores the tracker summary JSON; `-TrackQuiet` suppresses the tracker’s job table; `-DisableCheckRuns` skips the check-runs table.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Workflow` | string | `validate.yml` | Workflow file/name passed to `gh workflow run`. |
| `Ref` | string | current branch | Target ref (branch/SHA). |
| `Repo` | string | inferred | OWNER/REPO slug when not auto-detectable. |
| `PollSeconds` | int | `10` | Interval when searching for the new run. |
| `MonitorPollSeconds` | int | `20` | Poll interval for job tracking. |
| `TimeoutSeconds` | int | `300` | Timeout for locating the run before monitoring. |
| `OutputPath` | string | - | Tracker summary output (forwarded to `Track-WorkflowRun`). |
| `Quiet` | switch | Off | Suppress high-level status logs. |
| `TrackQuiet` | switch | Off | Pass `-Quiet` to `Track-WorkflowRun`. |
| `DisableCheckRuns` | switch | Off | Skip enhanced check-run summary output. |

## Exit Codes
- Propagates `Track-WorkflowRun`’s exit code (and ultimately the workflow outcome).

## Related
- `tools/Track-WorkflowRun.ps1`
- `tools/Watch-OrchestratedRest.ps1`
