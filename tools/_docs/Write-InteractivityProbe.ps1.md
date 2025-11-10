# Write-InteractivityProbe.ps1

**Path:** `tools/Write-InteractivityProbe.ps1`

## Synopsis
Capture console interactivity signals (session ID, redirection flags, etc.) and append them to the GitHub Actions step summary plus stdout.

## Description
- Emits a `interactivity-probe/v1` JSON object with timestamp, OS version, session ID, and whether the current PowerShell host is interactive or redirected.
- Prints the JSON to stdout for log scraping and, when `GITHUB_STEP_SUMMARY` is available, renders a Markdown section summarizing the probe results for reviewers.
- Useful for diagnosing stuck runners or confirming whether a self-hosted agent is still able to display UI (required for certain LabVIEW flows).
- Has no parameters; simply call from a step.

## Outputs
- Stdout line containing the JSON payload.
- Step summary section (“### Interactivity Probe”) any time `GITHUB_STEP_SUMMARY` is set.

## Exit Codes
- `0` — Probe captured successfully (or summary not available).
- `!=0` — Unexpected PowerShell/runtime error writing JSON or summaries.

## Related
- `docs/LABVIEW_GATING.md` (runner health signals)
