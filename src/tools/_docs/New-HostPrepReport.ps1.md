# New-HostPrepReport.ps1

**Path:** `tools/report/New-HostPrepReport.ps1`

## Synopsis
Generates a Markdown block summarizing Host Prep runs (hardware prep, VIPM apply, etc.) for inclusion in PR comments or session index logs.

## Description
- Mirrors `New-LVCompareReport.ps1` but labels the section “Host Prep” so stakeholders can distinguish host readiness runs from compare suites.
- Callers provide the command line, transcript path, telemetry location, summary text, and warning text; the script assembles the Markdown with fenced code blocks for the summary and warnings.
- Handy when collating manual validation steps or attaching readiness evidence to a PR.

### Parameters
| Name | Type | Default |
| --- | --- | --- |
| `Label` | string | `host-prep-<timestamp>` |
| `Command` | string | `<paste command>` |
| `Transcript` | string | `<path>` |
| `Telemetry` | string | `<path>` |
| `Summary` | string | `<paste summary block>` |
| `Warnings` | string | `<warnings/errors>` |

## Outputs
- Markdown text written to stdout; callers can capture it in files or CI summaries.

## Related
- `tools/report/New-LVCompareReport.ps1`
- `tools/report/New-MissingInProjectReport.ps1`
