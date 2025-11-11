# Dev-Dashboard.psm1

**Path:** `tools/Dev-Dashboard.psm1`

## Synopsis
Core module behind the developer dashboard: ingests telemetry artifacts (watch, agent wait, LabVIEW snapshots, queue stats) and produces a consolidated snapshot for console/HTML reports.

## Description
- Provides helpers to read JSON/NDJSON files, resolve safe paths, and aggregate telemetry (watch lock, agent waits, compare outcomes, LabVIEW snapshots, stakeholder configs).
- `Get-DashboardSnapshot` returns a structured object describing health indicators, action items, and recent lab activity; consumed by `Dev-Dashboard.ps1`.
- Includes HTML rendering utilities (`ConvertTo-HtmlReport`), console writers, and logic to monitor watch telemetry for stalls/flaky recovery.
- Uses `ConsoleUx` helpers for consistent logging.

### Exported Functions (high-level)
| Function | Purpose |
| --- | --- |
| `Get-DashboardSnapshot` | Aggregate all telemetry into a snapshot for the requested group. |
| `Write-TerminalReport` | Pretty-print the snapshot to the console. |
| `ConvertTo-HtmlReport` | Produce the HTML dashboard from a snapshot. |
| `Get-DashboardActionItems` | Derive actionable issues (LabVIEW leaks, queue stalls, missing stakeholders). |

## Inputs
- Telemetry paths under `tests/results/` (watch logs, agent waits, labview snapshots, compare outcomes).
- Stakeholder mapping file specified via `Dev-Dashboard.ps1 -StakeholderPath`.

## Related
- `tools/Dev-Dashboard.ps1`
- `tools/ConsoleUx.psm1`
