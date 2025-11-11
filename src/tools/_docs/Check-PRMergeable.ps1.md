# Check-PRMergeable.ps1

**Path:** `tools/Check-PRMergeable.ps1`

## Synopsis
Polls the GitHub REST API until a pull request reports a stable mergeable state, then surfaces conflicts or rate-limit issues to CI.

## Description
- Requires `GH_TOKEN` or `GITHUB_TOKEN`; defaults to `$env:GITHUB_REPOSITORY` for the repo unless `-Repo` overrides it.
- Calls `GET /repos/{owner}/{repo}/pulls/{number}` in a loop while `mergeable_state` equals `unknown`, waiting `-DelaySeconds` between retries (up to `-Retries` attempts).
- Writes a JSON summary (`repo`, `number`, `mergeable`, `mergeableState`, `baseRef`, `headRef`, `attempts`) to stdout for troubleshooting.
- When `-FailOnConflict` is supplied, exits non-zero if GitHub reports `mergeable_state=dirty` or `mergeable=$false`, ensuring branch protection catches conflicts before bundle promotion.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Repo` | string | `$env:GITHUB_REPOSITORY` | OWNER/REPO slug. |
| `Number` | int (required) | - | Pull request number to inspect. |
| `Retries` | int | `6` | Additional attempts while the state is `unknown`. |
| `DelaySeconds` | int | `5` | Wait interval between retries. |
| `FailOnConflict` | switch | Off | Treat merge conflicts (`dirty`) as an error. |

## Exit Codes
- `0` when the API call succeeds (even if the PR is unmergeable unless `-FailOnConflict` is set).
- `1` when token/repo inputs are missing or `-FailOnConflict` trips.
- `!=0` bubbled from `Invoke-RestMethod` on HTTP failures.

## Related
- `tools/Branch-Orchestrator.ps1`
- `docs/LABVIEW_GATING.md`
