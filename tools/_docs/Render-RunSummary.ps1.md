# Render-RunSummary.ps1

**Path:** `tools/Render-RunSummary.ps1`

## Synopsis
Converts a `RunSummary` JSON file into Markdown (or plain text) for inclusion in GitHub step summaries or local logs.

## Description
- Imports `module/RunSummary/RunSummary.psm1` and calls `Convert-RunSummary` to format the summary file specified via `-InputFile` (or `RUNSUMMARY_INPUT_FILE` environment variable).
- Supports Markdown or plain-text output via `-Format`, writes to stdout, and optionally saves to `-OutFile`.
- `-AppendStepSummary` toggles inclusion of GitHub step-summary sections.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `InputFile` | string | `$env:RUNSUMMARY_INPUT_FILE` | Path to `run-summary.json`. |
| `Format` | string (`Markdown`,`Text`) | `Markdown` | Output format. |
| `OutFile` | string | - | Destination file (optional). |
| `AppendStepSummary` | switch | Off | Include GHA step-summary markup. |
| `Title` | string | `Compare Loop Run Summary` | Heading used in the Markdown output. |

## Outputs
- Formatted Markdown/text printed to stdout, optionally duplicated to `OutFile`.

## Related
- `module/RunSummary/RunSummary.psm1`
- `tools/render-ci-composite.ps1`
