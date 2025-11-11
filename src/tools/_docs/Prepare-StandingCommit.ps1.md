# Prepare-StandingCommit.ps1

**Path:** `tools/Prepare-StandingCommit.ps1`

## Synopsis
Stages deterministic changes for “standing priority” updates and writes `tests/results/_agent/commit-plan.json` so agents can hand off the next steps (or auto-commit).

## Description
- Adds all changes (`git add -A`), then unstages volatile files (`tests/results/**`, `.agent_priority_cache.json`) so only relevant files remain.
- Captures staged file names, constructs a suggested commit message (`chore(#<issue>): standing priority update` when possible), and records metadata (branch, labels, test expectations) in `commit-plan.json`.
- `-AutoCommit` attempts to run `git commit -m "<suggested>"` when files are staged; plan JSON notes whether the auto-commit succeeded.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `RepositoryRoot` | string | `.` | Repo to operate on. |
| `AutoCommit` | switch | Off | Commit immediately after preparing the plan. |

## Outputs
- `tests/results/_agent/commit-plan.json` following `agent-commit-plan/v1`.
- Optional commit if `-AutoCommit` succeeds.

## Related
- `tools/Print-AgentHandoff.ps1`
- `.agent_priority_cache.json`
