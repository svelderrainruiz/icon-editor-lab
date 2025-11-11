# Invoke-DevDashboard.ps1

**Path:** `tools/Invoke-DevDashboard.ps1`

## Synopsis
Convenience wrapper that runs `Dev-Dashboard.ps1`, saves JSON/HTML reports under `tests/results/dev-dashboard/`, and optionally emits JSON-only output.

## Description
- Ensures the output directory exists, then calls `tools/Dev-Dashboard.ps1` with `-Group` (default `pester-selfhosted`) and `-ResultsRoot`. By default it requests both HTML (`dashboard.html`) and JSON (`dashboard.json`).
- `-JsonOnly` skips HTML generation and prints the JSON-only location.
- Intended for local usage (`OneButton-CI`, runbook prep) so engineers can snapshot dashboard telemetry without manually running the CLI.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Group` | string | `pester-selfhosted` | Dashboard group id. |
| `ResultsRoot` | string | `tests/results` | Telemetry root passed to the dashboard CLI. |
| `OutputRoot` | string | `tests/results/dev-dashboard` | Where HTML/JSON outputs are stored. |
| `JsonOnly` | switch | Off | Skip HTML generation, produce JSON only. |

## Exit Codes
- `0` when the dashboard ran successfully; non-zero when the underlying CLI errors.

## Related
- `tools/Dev-Dashboard.ps1`
