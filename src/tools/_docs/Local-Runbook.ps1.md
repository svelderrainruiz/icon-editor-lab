# Local-Runbook.ps1

**Path:** `tools/Local-Runbook.ps1`

## Synopsis
Runs the integration runbook locally with lightweight profiles (quick/compare/loop) before pushing to CI.

## Description
- Sets `RUNBOOK_LOOP_*` environment variables (iterations=1, quick loop) and calls `scripts/Invoke-IntegrationRunbook.ps1` with the requested phases.
- Profiles (`quick`, `compare`, `loop`, `full`) map to common phase sets; specify `-Phases` or `-All` to override, and `-IncludeLoop` to append the `Loop` phase.
- `-FailOnDiff` causes loop diffs to fail locally; `-JsonReport` captures the runbook summary; `-PassThru` forwards the runbook’s detailed result object.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `All` | switch | Off | Run all phases without filtering. |
| `Phases` | string[] | profile-based | Explicit comma-separated phases (Prereqs, ViInputs, Compare, Loop, etc.). |
| `Profile` | string | `quick` | Named profile to run (`quick`, `compare`, `loop`, `full`). |
| `IncludeLoop` | switch | Off | Append the `Loop` phase to the selected set. |
| `FailOnDiff` | switch | Off | Sets `RUNBOOK_LOOP_FAIL_ON_DIFF=1`. |
| `JsonReport` | string | - | Destination JSON report (forwarded to the runbook). |
| `PassThru` | switch | Off | Returns the runbook result object. |

## Exit Codes
- Mirrors `scripts/Invoke-IntegrationRunbook.ps1` (non-zero when phases fail).

## Related
- `scripts/Invoke-IntegrationRunbook.ps1`
- `tools/Local-RunTests.ps1`
