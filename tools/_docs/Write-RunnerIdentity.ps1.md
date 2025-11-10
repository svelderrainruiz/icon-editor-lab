# Write-RunnerIdentity.ps1

**Path:** `tools/Write-RunnerIdentity.ps1`

## Synopsis
Emit a short runner metadata block (name, OS/arch, repo/ref, run id, optional sample id) to the GitHub step summary.

## Description
- Reads standard GitHub env vars (`RUNNER_NAME`, `RUNNER_OS`, `RUNNER_ARCH`, `GITHUB_REPOSITORY`, `GITHUB_RUN_ID`, `GITHUB_REF_NAME`).
- Creates a markdown section (`### Runner`) with bullet points; includes `sample_id` when supplied via `-SampleId`.
- Automatically exits when `GITHUB_STEP_SUMMARY` is unset and logs notices instead of throwing on errors, keeping workflows resilient.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `SampleId` | string | — | Optional identifier (e.g., rerun sample) printed in the summary. |

## Outputs
- Markdown appended to `GITHUB_STEP_SUMMARY`.

## Related
- `tools/Write-RunProvenance.ps1`
