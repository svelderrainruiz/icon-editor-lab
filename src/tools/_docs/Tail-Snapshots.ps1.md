# Tail-Snapshots.ps1

**Path:** `tools/Tail-Snapshots.ps1`

## Synopsis
Continuously tails a metrics-snapshot NDJSON file (e.g., `metrics-snapshot-v2`) and pretty-prints iteration/diff/error counts plus percentile metrics.

## Description
- Opens the snapshot file in read share mode, reads new JSON lines as they arrive, and prints a formatted line containing iteration, diff count, error count, average seconds, and configured percentile columns.
- Auto-detects percentile keys from the first object unless `-PercentileKeys` is specified. Useful when monitoring long-running comparators in real time.

### Parameters
| Name | Type | Default |
| --- | --- | --- |
| `Path` | string (required) | Snapshot NDJSON file. |
| `IntervalSeconds` | double | `1.5` | Poll interval when at EOF. |
| `PercentileKeys` | string | auto | Comma/space separated list (e.g., `p50,p90,p99`). |

## Outputs
- Writes formatted lines to stdout; continues until interrupted (Ctrl+C).

## Related
- `tools/Write-FixtureValidationSummary.ps1` (produces metrics snapshots)
