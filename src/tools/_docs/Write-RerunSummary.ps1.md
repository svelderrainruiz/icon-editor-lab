# Write-RerunSummary.ps1

**Path:** `tools/Write-RerunSummary.ps1`

## Synopsis
Generate a richer rerun summary (command + workflow link + optional sample note) and append it to `GITHUB_STEP_SUMMARY`.

## Description
- Collects repository/ref/workflow metadata from the environment (overridable via parameters) and constructs a `gh workflow run "<WorkflowName>" ...` command string.
- Optionally includes `include_integration` and `sample_id` flags, emitting a note when `-EmitSampleNote` is used but no `SampleId` was provided.
- If `WorkflowFile` is not supplied, attempts to parse `GITHUB_WORKFLOW_REF` to derive a clickable workflow URL in the summary.
- Designed for self-hosted and CI runners that already run PowerShell; avoids nested shell calls by writing Markdown directly.
- No step summary output is produced when `GITHUB_STEP_SUMMARY` is unset.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `WorkflowName` | string (required) | — | Display name passed to `gh workflow run`. |
| `WorkflowFile` | string | Auto | Workflow YAML path; used to build GitHub URL. |
| `RefName` | string | `GITHUB_REF_NAME` | Branch/tag forwarded to `gh workflow run -r`. |
| `SampleId` | string | — | Inject `-f sample_id=...` if provided. |
| `IncludeIntegration` | string | — | Inject `-f include_integration=...`. |
| `WorkflowRef` | string | `GITHUB_WORKFLOW_REF` | Used to infer workflow file when not supplied. |
| `Repository` | string | `GITHUB_REPOSITORY` | Creates GitHub link in the summary. |
| `EmitSampleNote` | switch | Off | Adds a note when no `SampleId` was provided. |

## Outputs
- Markdown block under “### Re-run With Same Inputs” written to `GITHUB_STEP_SUMMARY`, containing the command, optional note, and workflow URL.

## Exit Codes
- `0` — Summary written or skipped (when env var missing).
- `!=0` — Unexpected errors writing the summary file.

## Related
- `tools/Write-RerunHint.ps1`
- `.github/workflows/*.yml` (uses this helper in publish/validate jobs)
