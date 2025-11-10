# Trigger-StandingWorkflow.ps1

**Path:** `tools/Trigger-StandingWorkflow.ps1`

## Synopsis
Decide whether the “standing priority” workflow should run and, when required, invoke `tools/Run-LocalBackbone.ps1`.

## Description
- Detects the repository root (current directory or `-RepositoryRoot`) and inspects `git status`, ignoring transient paths such as `tests/results/`.
- Reads agent artifacts (`tests/results/_agent/commit-plan.json` and `post-commit.json`) plus branch divergence (`git rev-list --count @{u}..HEAD`) to determine why work remains (dirty files, pending pushes, missing plan artifacts, etc.).
- Emits `tests/results/_agent/standing-workflow.json` summarizing the decision (`shouldRun`, `reasons`, dirty file list, ahead count, force/plan flags) so CI or human reviewers can audit the call.
- When reasons exist (or `-Force`), launches `tools/Run-LocalBackbone.ps1`; otherwise prints a green “workflow not required” message.
- `-PlanOnly` writes the JSON plan but skips execution, enabling dry runs from pre-commit hooks or watchers.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `PlanOnly` | switch | Off | Record rationale only; do not execute `Run-LocalBackbone`. |
| `Force` | switch | Off | Run regardless of detected reasons/cleanliness. |
| `RepositoryRoot` | string | Auto | Override repo discovery (`git rev-parse --show-toplevel`). |

## Outputs
- `tests/results/_agent/standing-workflow.json` (decision payload and dirty file details).
- Console summary explaining whether the standing workflow ran and why.

## Exit Codes
- `0` — Plan generated and, if invoked, `Run-LocalBackbone` completed successfully.
- `!=0` — Repository detection failed, a required artifact was unreadable, or the delegated workflow failed.

## Related
- `tools/Run-LocalBackbone.ps1`
- `docs/LABVIEW_GATING.md` (standing workflow policy)
