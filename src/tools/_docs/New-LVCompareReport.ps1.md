# New-LVCompareReport.ps1

**Path:** `tools/report/New-LVCompareReport.ps1`

## Synopsis
Formats a Markdown snippet summarizing an LVCompare suite run (command, transcript, telemetry, summary text, warnings) for pasting into session index or issue comments.

## Description
- Accepts string parameters for each section and emits a Markdown block with consistent headings:
  - `### LVCompare Suite (Label: <Label>)`
  - Inline code showing the command, fenced blocks for the summary/warnings, and plain links for transcript + telemetry paths.
- Designed for manual workflows where an engineer copies the resulting block into PR comments or the `_agent/report` summaries; automation scripts can capture the string and append it to output files.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Label` | string | `lvcompare-<timestamp>` | Human-readable identifier for the run. |
| `Command` | string | `<paste command>` | Typically the full `pwsh -File ...` line. |
| `Transcript` | string | `<path>` | Link/path to the transcript log. |
| `Telemetry` | string | `<session-index path>` | Path to relevant telemetry JSON. |
| `Summary` | string | `<paste summary block>` | Multi-line summary inserted inside a fenced block. |
| `Warnings` | string | `<warnings/errors>` | Captured warnings (also fenced). |

## Outputs
- Writes the Markdown snippet to stdout; callers can redirect to `.md` files or embed in CI step summaries.

## Related
- `tools/report/New-HostPrepReport.ps1`
- `tools/report/New-MissingInProjectReport.ps1`
- `tools/Publish-VICompareSummary.ps1`
