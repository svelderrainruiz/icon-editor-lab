# LabVIEWPidTracker.psm1

**Path:** `tools/LabVIEWPidTracker.psm1`

## Synopsis
Keeps a rolling JSON record of LabVIEW processes launched during CLI operations so dev-mode reliability runs can detect rogue or leaked LabVIEW instances.

## Description
- `Start-LabVIEWPidTracker` (called by `tools/LabVIEWCli.psm1`) inspects currently running `LabVIEW.exe` processes, tries to reuse an existing PID recorded in the tracker file, and writes/updates `labview-pid-tracker/v1` JSON at the requested `TrackerPath` (typically `tests/results/_cli/_agent/labview-pid.json`). Observations capture timestamp, PID, whether the process was reused, and the source (`labview-cli:init`, `dispatcher`, etc.).
- `Stop-LabVIEWPidTracker` appends a `finalize` observation describing whether the tracked PID is still alive, what step triggered the shutdown, any timeout/error context, and a caller-provided `Context` object (converted to an ordered PSCustomObject for deterministic diffs). Only the last 25 observations are retained to keep files small.
- `Resolve-LabVIEWPidContext` normalizes arbitrary hashtables/arrays into ordered PSCustomObjects so downstream telemetry (session index, `_agent/reports`) can diff reliably.

### Key Functions
| Function | Purpose |
| --- | --- |
| `Start-LabVIEWPidTracker -TrackerPath <path> -Source <label>` | Initializes/updates tracker JSON, capturing existing LabVIEW processes and candidate list. Returns the new state object (pid, running, observations). |
| `Stop-LabVIEWPidTracker -TrackerPath <path> -Source <label> [-Pid <int>] [-Context <object>]` | Records the final state, marks whether the PID is still running, and appends the optional context payload. |
| `Resolve-LabVIEWPidContext -Context <object>` | Sanitizes caller-provided context before it is embedded in the JSON document. |

## Outputs
- JSON file following `labview-pid-tracker/v1` schema with `observations[]`, `pid`, `running`, `reused`, and optional `context/contextSource`. Consumers include `docs/LABVIEW_GATING.md` reliability gates and session index summaries.

## Related
- `tools/LabVIEWCli.psm1`
- `docs/LABVIEW_GATING.md`
