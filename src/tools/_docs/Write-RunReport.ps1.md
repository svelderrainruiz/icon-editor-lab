# Write-RunReport.ps1

**Path:** `tools/report/Write-RunReport.ps1`

## Synopsis
Persist run-level metadata (command, summary, warnings, telemetry links) to `tests/results/_agent/reports/<kind>/label-timestamp.json`.

## Description
- Supports four report kinds: `host-prep`, `missing-in-project`, `unit-tests`, `lvcompare`.
- Resolves the repo root (or `COMPAREVI_REPORTS_ROOT` override), ensures `tests/results/_agent/reports/<kind>` exists, and writes a JSON payload with schema `icon-editor/report@v1`.
- Payload fields:
  - `kind`, `label`, `command`, `summary`, `warnings`
  - `transcriptPath`, `telemetryPath`, `aborted`, `abortReason`
  - Optional `extra` hash table and `devModeTelemetry` (when `TelemetryLinks` provided for host-prep).
- File name format: `<Label>-<yyyyMMddTHHmmssfff>.json`, making it easy to keep multiple snapshots per label.
- Returns the full path so callers can upload or link the report.

### Parameters
| Name | Type | Notes |
| --- | --- | --- |
| `Kind` | string (required) | One of `host-prep`,`missing-in-project`,`unit-tests`,`lvcompare`. |
| `Label` | string (required) | Report label (`vi-history`, `unit-tests`, etc.). |
| `Command` | string (required) | Command line executed. |
| `Summary` | string (required) | Short description of the outcome. |
| `Warnings` | string | Optional warning text. |
| `TranscriptPath` | string | Transcript/log file path. |
| `TelemetryPath` | string | Path to telemetry JSON. |
| `TelemetryLinks` | hashtable | Additional telemetry references (host-prep only). |
| `Aborted` | switch | Flag report as aborted. |
| `AbortReason` | string | Reason for abort. |
| `Extra` | hashtable | Arbitrary metadata appended to the payload. |

## Outputs
- JSON report under `tests/results/_agent/reports/<kind>/`.
- Console message with the generated path.

## Related
- `tools/report/New-HostPrepReport.ps1` (calls this helper)
- `tests/results/_agent/reports/`
