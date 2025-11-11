# Run-OneButtonValidate.ps1

**Path:** `tools/Run-OneButtonValidate.ps1`

## Synopsis
Runs the “one-button validate” automation: linting, PrePush gates, workflow normalization, optional stage/commit/push/PR, and summary generation.

## Description
- Executes a curated list of validation steps (tracked artifact checks, actionlint/PrePush gates, Markdown lint, docs link check, workflow drift, loop determinism, environment snapshots, etc.) using `Invoke-Step` to capture status/duration.
- Optional automation: `-Stage`, `-Commit`, `-Push`, `-CreatePR` trigger git operations after validation passes. `-OpenResults` opens the `tests/results` folder at the end.
- Writes a Markdown summary table to `tests/results/_agent/onebutton-summary.md` so teams can review which steps ran and whether they succeeded.

### Parameters
| Name | Type | Notes |
| --- | --- | --- |
| `Stage` | switch | Stage changes (`Check-WorkflowDrift.ps1 -Stage`). |
| `Commit` | switch | Commit with a canned message after staging. |
| `Push` | switch | Push (creates upstream if needed). |
| `CreatePR` | switch | Create or update a PR via `gh`. |
| `OpenResults` | switch | Opens `tests/results` in Explorer/Finder after completion. |

## Outputs
- Console logs for each validation step plus `tests/results/_agent/onebutton-summary.md`.

## Related
- `tools/Check-WorkflowDrift.ps1`
- `tools/PrePush-Checks.ps1`
