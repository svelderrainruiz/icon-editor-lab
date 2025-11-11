# Write-RerunHint.ps1

**Path:** `tools/Write-RerunHint.ps1`

## Synopsis
Append a short GitHub Actions step-summary block that shows how to re-run a workflow via `gh workflow run`, including optional integration flags and a sample ID.

## Description
- Requires `GITHUB_STEP_SUMMARY`; otherwise it no-ops (allowing the script to run locally without errors).
- Builds a `gh workflow run <workflow>` command pinned to the current repository/ref (`GITHUB_REPOSITORY` / `GITHUB_REF_NAME`) and adds `-f sample_id=...` as well as `-f include_integration=...` when parameters are provided.
- `SampleId` defaults to a new GUID when omitted so reviewers can paste a ready-to-run command.
- Renders the command in a fenced Bash block under the “### Re-run (gh)” heading for easy copy/paste.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Workflow` | string (required) | — | Workflow name or file accepted by `gh workflow run`. |
| `IncludeIntegration` | string | — | Optional flag forwarded as `-f include_integration=<value>`. |
| `SampleId` | string | Auto GUID | Identifier pushed to `-f sample_id=<value>`. |

## Outputs
- Step summary snippet containing the rerun command when `GITHUB_STEP_SUMMARY` is available.

## Exit Codes
- `0` — Summary written or skipped (no summary env var).
- `!=0` — Rare PowerShell errors (e.g., inability to write the summary file).

## Related
- `tools/Write-RerunSummary.ps1`
- `docs/LABVIEW_GATING.md` (rerun guidance)
