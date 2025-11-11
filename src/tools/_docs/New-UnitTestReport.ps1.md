# New-UnitTestReport.ps1

**Path:** `tools/report/New-UnitTestReport.ps1`

## Synopsis
Writes a Markdown summary for unit-test runs (command, summary text, transcript, telemetry, warnings).

## Description
- Formats output identical to the other `New-*Report.ps1` helpers but labels the section “Unit Test Suite”.
- Feed it the command line, transcript path, unit-test telemetry (e.g., JUnit XML), summary text, and warnings to get a ready-to-share Markdown block.
- Useful for capturing unit-test evidence when handing off between agents or commenting on PRs.

### Parameters
| Name | Type | Default |
| --- | --- | --- |
| `Label` | string | `unit-tests-<timestamp>` |
| `Command` | string | `<paste command>` |
| `Transcript` | string | `<path>` |
| `Telemetry` | string | `<UnitTestReport.xml path>` |
| `Summary` | string | `<paste summary block>` |
| `Warnings` | string | `<warnings/errors>` |

## Outputs
- Markdown string printed to stdout.

## Related
- `tools/report/New-LVCompareReport.ps1`
- `tools/report/New-HostPrepReport.ps1`
