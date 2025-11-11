# Write-FixtureDriftSummary.ps1

**Path:** `tools/Write-FixtureDriftSummary.ps1`

## Synopsis
Summarize fixture drift results by reading `drift-summary.json` (and related handshake/ PID tracker data) and writing a concise block to `GITHUB_STEP_SUMMARY`.

## Description
- Defaults to `results/fixture-drift/drift-summary.json` but both directory and filename are configurable.
- When the summary JSON is missing or invalid, records that fact in the step summary instead of failing.
- Prints counts (missing, hashMismatch, manifestError, etc.) along with any notes or LabVIEW PID tracker details captured by fixture-drift runs.
- If `_handshake/ready.json` or `_handshake/end.json` exist inside the drift results, the script appends handshake statuses to the summary.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Dir` | string | `results/fixture-drift` | Root directory for drift artifacts. |
| `SummaryFile` | string | `drift-summary.json` | JSON file to parse within `Dir`. |

## Outputs
- Markdown appended to `GITHUB_STEP_SUMMARY` describing drift status, counts, tracker info, and notes.

## Related
- `tools/Fixture-Drift/*.ps1`
