# Write-AgentContext.ps1

**Path:** `tools/Write-AgentContext.ps1`

## Synopsis
Collect repo + agent diagnostics (branch, env toggles, wait sessions, rogue LV processes, pester summary) and emit both JSON and Markdown context artifacts.

## Description
- Reads metadata from git (`branch`, `headSha`), `gh repo view`, and `AGENT_HANDOFF.txt` to capture the current repo state.
- Records LabVIEW-related env toggles (`LV_SUPPRESS_UI`, `CLEAN_LV_BEFORE`, etc.) plus agent wait-session status (`tests/results/_agent/sessions/*/wait-last.json`).
- Pulls recent LVCompare notices (default `tests/results/_agent/_lvcompare_notice`) and, when available, runs `tools/Detect-RogueLV.ps1` to record live LabVIEW/LVCompare processes.
- Includes the latest `pester-summary.json` counts for quick CI triage.
- Writes both JSON (`tests/results/_agent/context/context.json`) and Markdown (`context.md`). The Markdown is optionally appended to `GITHUB_STEP_SUMMARY` when `-AppendToStepSummary` is set.
- Returns/prints the JSON path so other scripts can link to it or upload as an artifact.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `ResultsDir` | string | `tests/results` | Root for `_agent`, pester, and notice artifacts. |
| `MaxNotices` | int | `10` | Maximum LVCompare notice files to read. |
| `AppendToStepSummary` | switch | Off | Append the Markdown summary to the GitHub step summary file. |
| `Quiet` | switch | Off | Suppress console message that points to the context JSON. |

## Outputs
- JSON: `tests/results/_agent/context/context.json`
- Markdown: `tests/results/_agent/context/context.md`
- Optional addition to `GITHUB_STEP_SUMMARY`.

## Related
- `tools/Detect-RogueLV.ps1`
- `tests/results/_agent/handoff/`
