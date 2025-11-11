# Agent-Wait.ps1

**Path:** `tools/Agent-Wait.ps1`

## Synopsis
Records start/stop metadata for self-hosted agent pauses so GitHub Actions and local runs can audit wait windows.

## Description
- `Start-AgentWait` creates `_agent/sessions/<id>/wait-marker.json` with the reason, expected duration, tolerance, and runner context (workflow, job, SHA, actor). It also writes a short summary block to `GITHUB_STEP_SUMMARY`.
- `End-AgentWait` reads the marker, computes the elapsed time, and persists both `wait-last.json` (latest result) and `wait-log.ndjson` (history) alongside a Markdown summary. The function flags waits that drift outside the allowed tolerance.
- Both helpers are dot-source friendly; the script exports the two functions when imported as a module. Failures exit non-zero so CI jobs surface a gating error instead of silently hanging.

### Parameters
| Command | Name | Type | Default | Notes |
| --- | --- | --- | --- | --- |
| `Start-AgentWait` | `Reason` | string | `unspecified` | Free-text description shown in logs and summaries. |
| `Start-AgentWait` | `ExpectedSeconds` | int | `90` | Target duration; used when calculating on-time vs drift. |
| `Start-AgentWait` | `ResultsDir` | string | `tests/results` | Root that receives the `_agent/sessions/<id>/...` artifacts. |
| `Start-AgentWait` | `ToleranceSeconds` | int | `5` | Allowed +/- drift when validating the elapsed seconds. |
| `Start-AgentWait` | `Id` | string | `default` | Session/channel name so multiple waits can run in parallel. |
| `End-AgentWait` | `ResultsDir` | string | `tests/results` | Must match the directory used when the wait started. |
| `End-AgentWait` | `ToleranceSeconds` | int | marker value | Overrides the tolerance stored in the marker (optional). |
| `End-AgentWait` | `Id` | string | `default` | Session id to close; the marker is left in place for chained waits. |

## Outputs
- `_agent/sessions/<id>/wait-marker.json` (start metadata)
- `_agent/sessions/<id>/wait-last.json` + `wait-log.ndjson` (results stream)
- GitHub step summary excerpt documenting the pause and outcome.

## Exit Codes
- `0` on success.
- `!=0` when marker validation fails or `git` context cannot be resolved.

## Related
- `tools/Agent-WaitHook.Profile.ps1`
- `docs/LABVIEW_GATING.md`
