# Debug-ChildProcesses.ps1

**Path:** `tools/Debug-ChildProcesses.ps1`

## Synopsis
Snapshots key LabVIEW/Pwsh console processes, capturing memory usage and command lines to help diagnose leaked children after CI jobs.

## Description
- Enumerates a configurable list of process names (default `pwsh`, `conhost`, `LabVIEW`, `LVCompare`, `LabVIEWCLI`, `g-cli`, `VIPM`).
- For each group, gathers PID, working set, paged memory, window title, and command line (truncated to 2 KB) and writes them to `tests/results/_agent/child-procs.json` (`child-procs-snapshot/v1`).
- Optionally appends a Markdown summary to `GITHUB_STEP_SUMMARY`.
- Intended for ISO gating steps such as DevMode reliability and compare sweeps where residual LabVIEW instances are unacceptable.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `ResultsDir` | string | `tests/results` | Root used when creating `_agent/child-procs.json`. |
| `Names` | string[] | `pwsh, conhost, LabVIEW, LVCompare, LabVIEWCLI, g-cli, VIPM` | Process names to inspect; case-insensitive. |
| `AppendStepSummary` | switch | Off | Adds a short summary table to the GitHub step summary. |

## Outputs
- `tests/results/_agent/child-procs.json`
- Optional step-summary lines describing counts and memory per process group.

## Exit Codes
- `0` on success; non-zero only when unexpected exceptions occur.

## Related
- `tools/Capture-LabVIEWSnapshot.ps1`
- `docs/LABVIEW_GATING.md`
