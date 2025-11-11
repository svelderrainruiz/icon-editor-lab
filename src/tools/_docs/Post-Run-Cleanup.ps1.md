# Post-Run-Cleanup.ps1

**Path:** `tools/Post-Run-Cleanup.ps1`

## Synopsis
Centralizes LabVIEW/LVCompare shutdown after CI runs by honoring requests written to `tests/results/_agent/post/requests` and invoking the appropriate close helpers exactly once.

## Description
- Collects JSON request files produced by `Register-PostRunRequest` (source/tool metadata included) and decides whether LabVIEW and/or LVCompare need to be closed even if the current job never launched them directly.
- Uses `tools/Once-Guard.psm1` so `Close-LabVIEW.ps1` / `Close-LVCompare.ps1` run at most once per workspace; retries with `Force-CloseLabVIEW.ps1` when stubborn processes remain.
- Logs activity to `tests/results/_agent/post/post-run-cleanup.log` and captures pre/post process snapshots so rogue PID detection in `docs/LABVIEW_GATING.md` has traceability.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `CloseLabVIEW` | switch | Off | Force a LabVIEW close even if no request file exists (used in interactive runs). |
| `CloseLVCompare` | switch | Off | Force LVCompare cleanup regardless of pending requests. |

## Outputs
- `tests/results/_agent/post/post-run-cleanup.log` plus residual process warnings on stdout.
- Request files are deleted once processed so future runs don’t repeat the same cleanup.

## Exit Codes
- `0` – Cleanup finished (or nothing needed to be closed).
- `!=0` – Close helper failed after retries (script throws with context).

## Related
- `tools/PostRun/PostRunRequests.psm1`
- `tools/Close-LabVIEW.ps1`, `tools/Close-LVCompare.ps1`, `tools/Force-CloseLabVIEW.ps1`
- `docs/LABVIEW_GATING.md`
