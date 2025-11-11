# Agent-WaitHook.Profile.ps1

**Path:** `tools/Agent-WaitHook.Profile.ps1`

## Synopsis
Wraps the interactive PowerShell prompt so every wait marker started via `Agent-Wait.ps1` is automatically closed when the prompt reappears.

## Description
- Dot-sources `Agent-Wait.ps1`, then exposes two helpers:
  - `Enable-AgentWaitHook` – starts a wait (same parameters as `Start-AgentWait`) and overwrites `function:Prompt`. Each time the prompt renders, it inspects `_agent/sessions/<id>/wait-marker.json` and closes it via `End-AgentWait` if no result exists.
  - `Disable-AgentWaitHook` – restores the original prompt and leaves existing markers untouched.
- Maintains global state (`__AgentWaitHook`) tracking the saved prompt, active session id, and results directory so the hook can be toggled multiple times per shell.
- Useful for local debugging: kick off a wait before running long LabVIEW steps and the hook will emit wait summaries as soon as focus returns.

### Parameters (Enable-AgentWaitHook)
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Reason` | string | `unspecified` | Logged in the wait marker + step summary. |
| `ExpectedSeconds` | int | `90` | Target duration before the prompt is expected back. |
| `ToleranceSeconds` | int | `5` | +/- window before drift is flagged. |
| `ResultsDir` | string | `tests/results` | Location of `_agent/sessions/<id>` artifacts. |
| `Id` | string | `default` | Session channel so multiple waits can co-exist. |

## Exit Codes
- `0` on success; non-zero only surfaces when `Start-AgentWait`/`End-AgentWait` raise errors (rare in interactive use).

## Related
- `tools/Agent-Wait.ps1`
- `docs/LABVIEW_GATING.md`
