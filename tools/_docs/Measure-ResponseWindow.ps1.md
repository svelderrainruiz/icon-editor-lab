# Measure-ResponseWindow.ps1

**Path:** `tools/Measure-ResponseWindow.ps1`

## Synopsis
Simple stopwatch utility for tracking “agent response windows”: start a timer before a wait, stop it afterward, and optionally fail when the elapsed time exceeds the tolerance.

## Description
- Relies on `Agent-Wait.ps1` to persist markers under `tests/results/_agent/sessions/<id>/`.
- `-Action Start` writes a marker (reason, expected seconds, tolerance, timestamp). `-Action End` reads the marker, computes elapsed/expected deltas, and prints a machine-readable line. `-Action Status` dumps the last marker/result.
- `-FailOnOutsideMargin` returns exit code 2 when the elapsed time exceeds the tolerance window, allowing CI to highlight SLA misses.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Action` | string (`Start`,`End`,`Status`) | `End` |
| `Reason` | string | `unspecified` | Context for the wait window. |
| `ExpectedSeconds` | int | `90` | Target duration used for tolerance math. |
| `ToleranceSeconds` | int | `5` | Margin before the window is considered violated. |
| `ResultsDir` | string | `tests/results` | Root for `_agent/sessions`. |
| `Id` | string | `default` | Session identifier (multiple overlapping timers can use different IDs). |
| `FailOnOutsideMargin` | switch | Off | `End` exits non-zero when elapsed exceeds tolerance. |

## Outputs
- `Start`: marker path; `End`: `RESULT reason=... elapsed=...` line + exit code; `Status`: prints last marker/last result info.

## Related
- `tools/Agent-Wait.ps1`
- `docs/LABVIEW_GATING.md`
