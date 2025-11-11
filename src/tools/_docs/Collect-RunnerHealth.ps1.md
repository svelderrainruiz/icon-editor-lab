# Collect-RunnerHealth.ps1

**Path:** `tools/Collect-RunnerHealth.ps1`

## Synopsis
Records runner health telemetry: service status, disk space, key processes, and optional GitHub queue data for CI diagnostics.

## Description
- Detects the current repo slug (via `git remote origin`) and workspace drive stats, then snapshots OS/PowerShell versions.
- Probes the configured runner service (`-ServiceName`, defaults to `actions.runner.enterprises-labview-community-ci-cd.research`) via `Get-Service`/`systemctl`.
- When `-IncludeGhApi` is set and the `gh` CLI is available, queries workflow queues and enterprise runner pools (requires `GH_TOKEN/GITHUB_TOKEN`).
- Captures `pwsh`, `LVCompare`, and `LabVIEW` processes.
- Outputs `runner-health/v1` JSON to `<ResultsDir>/_agent/runner-health.json` when `-EmitJson` is set, and can append a GitHub Step Summary (`-AppendSummary`).

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Enterprise` | string | *empty* | Enterprise slug for runner stats when using `gh api`. |
| `Repo` | string | auto | Override repo slug if `git` remotes are unavailable. |
| `ServiceName` | string | `actions.runner.enterprises-labview-community-ci-cd.research` | Runner service to probe. |
| `ResultsDir` | string | `tests/results` | Root used for JSON emission. |
| `AppendSummary` | switch | Off | Adds a summary block to `GITHUB_STEP_SUMMARY`. |
| `EmitJson` | switch | Off | Writes `_agent/runner-health.json`. |
| `IncludeGhApi` | switch | Off | Enable queue snapshots via GitHub API. |

## Outputs
- Optional JSON (`tests/results/_agent/runner-health.json`) and step-summary block.

## Exit Codes
- `0` on success; non-zero for critical failures (missing tools, JSON write errors).

## Related
- `docs/LABVIEW_GATING.md`
