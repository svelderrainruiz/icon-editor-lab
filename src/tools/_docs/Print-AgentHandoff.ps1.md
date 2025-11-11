# Print-AgentHandoff.ps1

**Path:** `tools/Print-AgentHandoff.ps1`

## Synopsis
Summarizes the current CI/agent state (standing priorities, results, rogue LV processes, hook statuses) for quick human handoffs.

## Description
- Reads telemetry under `tests/results/_agent` (standing priority cache, handoff summaries, hook logs, rogue-LabVIEW reports) and prints annotated sections to the console (and optionally GitHub step summaries).
- `-ApplyToggles` trims or rotates `AGENT_HANDOFF.txt` entries; `-OpenDashboard` renders the Dev Dashboard for the specified group; `-AutoTrim` prunes stale watcher data.
- Emits watcher summaries, rogue process findings, hook statuses, and test results so the next engineer can resume work quickly.

### Parameters (subset)
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `ApplyToggles` | switch | Off | Apply auto-trim toggles described in handoff metadata. |
| `OpenDashboard` | switch | Off | Invoke `tools/Dev-Dashboard.ps1` after printing summaries. |
| `AutoTrim` | switch | Off | Trim watcher directories automatically. |
| `Group` | string | `pester-selfhosted` | Dashboard group when `-OpenDashboard`. |
| `ResultsRoot` | string | `tests/results` | Root containing `_agent` telemetry. |

## Outputs
- Console summary plus optional GitHub step summary entries and hook summary JSON (`tests/results/_agent/handoff/hook-summary.json`).

## Related
- `tools/Prepare-StandingCommit.ps1`
- `tools/Dev-Dashboard.ps1`
