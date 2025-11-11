# Guard-LabVIEWPersistence.ps1

**Path:** `tools/Guard-LabVIEWPersistence.ps1`

## Synopsis
Capture snapshots of running LabVIEW/LVCompare processes at key phases and log them to `labview-persistence.json` plus the GitHub step summary.

## Description
- Samples `LabVIEW.exe` and `LVCompare.exe` using `Get-Process`, recording counts and PIDs.
- Writes/updates `<ResultsDir>/labview-persistence.json` (JSON array, schema `labview-persistence/v1`) so CI runs can track LabVIEW presence over time (before/after compare, etc.).
- Optionally polls for up to `PollForCloseSeconds` to detect when LabVIEW closes shortly after a phase (sets `closedEarly = true`).
- Appends a markdown bullet to `GITHUB_STEP_SUMMARY` summarizing counts, PIDs, and whether LabVIEW closed early.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `ResultsDir` | string | `results/fixture-drift` | Directory where `labview-persistence.json` is stored. |
| `Phase` | string (required) | — | Label for this sampling event (e.g., `before-compare`). |
| `PollForCloseSeconds` | int | `0` | Optional polling window to detect LabVIEW closing soon after the sample. |

## Exit Codes
- `0` — Snapshot captured successfully.
- `!=0` — Only thrown when the script is invoked with `-ErrorAction Stop` and an unexpected error occurs (warnings by default).

## Related
- `tools/Detect-RogueLV.ps1`
- `tools/Warmup-LabVIEWRuntime.ps1`
- `docs/LABVIEW_GATING.md`
