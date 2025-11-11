# New-MissingInProjectReport.ps1

**Path:** `tools/report/New-MissingInProjectReport.ps1`

## Synopsis
Produces a Markdown snippet summarizing Missing-In-Project suite runs (command, transcript, summary, telemetry, warnings).

## Description
- Same structure as the other `New-*Report.ps1` helpers, but the heading reads “MissingInProject Suite”.
- Intended for copy/paste workflows when attaching MIP evidence to an issue or README; just feed the script the command, transcript, summary text (usually Pester output), telemetry file path, and warnings/errors.
- Outputs a self-contained Markdown block you can append to session index summaries.

### Parameters
| Name | Type | Default |
| --- | --- | --- |
| `Label` | string | `missinginproject-<timestamp>` |
| `Command` | string | `<paste command>` |
| `Transcript` | string | `<path>` |
| `Summary` | string | `<paste Pester summary>` |
| `Warnings` | string | `<warnings/errors>` |
| `Telemetry` | string | `<optional telemetry>` |

## Outputs
- Markdown string emitted to stdout.

## Related
- `tools/report/New-LVCompareReport.ps1`
- `tools/report/New-HostPrepReport.ps1`
