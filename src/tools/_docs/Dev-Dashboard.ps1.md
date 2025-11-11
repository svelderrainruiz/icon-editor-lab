# Dev-Dashboard.ps1

**Path:** `tools/Dev-Dashboard.ps1`

## Synopsis
CLI entry point that renders the developer dashboard snapshot (JSON, HTML, or console report) by aggregating watch telemetry, queue data, LabVIEW snapshots, and stakeholder info.

## Description
- Imports `Dev-Dashboard.psm1`, then calls `Get-DashboardSnapshot` for the requested `-Group` (default `pester-selfhosted`).
- Output options:
  - Console report (default unless `-Quiet`).
  - `-Html` writes an HTML report to `-HtmlPath` (default `tools/dashboard/dashboard.html`).
  - `-Json` emits the snapshot JSON to stdout (or repeatedly when `-Watch > 0`).
- `-Watch <seconds>` reruns the snapshot in a loop, clearing the console between iterations unless `-Quiet`.
- `-ResultsRoot` overrides where telemetry is read from (otherwise auto-detected); `-StakeholderPath` injects owners/channels metadata for the summary.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Group` | string | `pester-selfhosted` | Dashboard grouping (matches config entry). |
| `Html` / `HtmlPath` | switch / string | Off / `tools/dashboard/dashboard.html` | Enable HTML output and optional destination. |
| `Json` | switch | Off | Emit snapshot JSON (to stdout). |
| `Quiet` | switch | Off | Suppress console report. |
| `Watch` | int | `0` | Loop interval in seconds; 0 disables watch mode. |
| `ResultsRoot` | string | auto | Where to read telemetry artifacts (`tests/results`). |
| `StakeholderPath` | string | auto | Stakeholder mapping file. |

## Related
- `tools/Dev-Dashboard.psm1`
- `tests/results/_warmup/`, `_agent/`, `_watch/` (telemetry inputs)
