# Notify-Demo.ps1

**Path:** `tools/Notify-Demo.ps1`

## Synopsis
Example notification hook that prints a single-line summary of a run plus an optional environment reflection.

## Description
- Accepts status metadata (counts, run sequence, classification) and prints `Notify: Run#<N> ...` so you can see what would be sent to a real notification system.
- If `WATCH_STATUS` is present in the environment, echoes it for debugging watchers.
- Used in documentation, not production; serves as a template for building richer notification hooks.

### Parameters
| Name | Type | Notes |
| --- | --- | --- |
| `Status` | string | Result label (e.g., `passed`, `failed`). |
| `Failed` | int | Number of failures. |
| `Tests` | int | Total tests run. |
| `Skipped` | int | Skipped tests count. |
| `RunSequence` | int | Ordinal run number. |
| `Classification` | string | Arbitrary label. |

## Outputs
- Console lines summarizing the run and `WATCH_STATUS` (when set).

## Related
- `tools/WatcherInvoker.ps1`
