# Test-ProviderTelemetry.ps1

**Path:** `tools/Vipm/Test-ProviderTelemetry.ps1`

## Synopsis
Validate the VIPM provider comparison telemetry emitted by `Invoke-ProviderComparison` and fail early when scenarios/providers report non-success statuses.

## Description
- Reads the JSON telemetry matrix (default `tests/results/_agent/vipm-provider-matrix.json`), ensuring the file exists and contains valid JSON.
- Treats the payload as an array of `{ scenario, provider, status, error }` entries.
- Flags any entry whose `status` is not in `-AllowStatuses` (default `success`) and throws with a concise summary, allowing CI to highlight regressions immediately.
- `-TreatMissingAsWarning` downgrades missing telemetry files to warnings, allowing optional runs to pass when the matrix hasn’t been generated yet.
- Returns the filtered entries so callers can perform additional analysis when needed.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `InputPath` | string | `tests/results/_agent/vipm-provider-matrix.json` | Telemetry JSON path. |
| `AllowStatuses` | string[] | `@('success')` | Allowed status values. |
| `TreatMissingAsWarning` | switch | Off | Emit warning and return empty list when file absent. |

## Outputs
- Console success message (count + allowed statuses).
- Returns the telemetry entries whose statuses matched the allowlist.

## Exit Codes
- `0` — Telemetry file present (or warned) and entries satisfied the allowlist.
- Non-zero — Missing/empty file (without warning mode) or entries with disallowed statuses.

## Related
- `tools/Vipm/Invoke-ProviderComparison.ps1`
