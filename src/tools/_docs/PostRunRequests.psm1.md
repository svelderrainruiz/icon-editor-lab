# PostRunRequests.psm1

**Path:** `tools/PostRun/PostRunRequests.psm1`

## Synopsis
Provides `Register-PostRunRequest` so other scripts can queue LabVIEW/LVCompare cleanup work for `tools/Post-Run-Cleanup.ps1`.

## Description
- Writes JSON request files to `tests/results/_agent/post/requests`. Each file records the request `name` (`close-labview` or `close-lvcompare`), the `source` script, timestamp, and optional metadata (version, bitness, etc.).
- Ensures the requests directory exists and returns the path to the file so callers can log or attach it to telemetry.
- Consumed by the cleanup orchestrator to decide which close helpers to execute after the main job finishes.

## Related
- `tools/Post-Run-Cleanup.ps1`
- `docs/LABVIEW_GATING.md`
