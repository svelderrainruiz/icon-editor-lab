# Prime-LVCompare.ps1

**Path:** `tools/Prime-LVCompare.ps1`

## Synopsis
Lightweight readiness probe that runs LVCompare.exe against two VIs, records timing, verifies expected diff/no-diff behavior, and emits NDJSON telemetry.

## Description
- Resolves LVCompare/LabVIEW paths via config/env vars, launches LVCompare with deterministic flags (`-noattr -nofp -nofppos -nobd -nobdcosm` unless overridden), and measures elapsed time/exit code.
- Optional guards:
  - `-ExpectDiff` or `-ExpectNoDiff` to enforce the exit code.
  - `-KillOnTimeout` to terminate LVCompare after `TimeoutSeconds`.
  - `-LeakCheck` to ensure no lingering LabVIEW/LVCompare processes remain (writes JSON summary).
- Writes NDJSON events (`prime-lvcompare-v1`) and leak summaries to `tests/results/_warmup` by default so CI dashboards can display warm-up health.

### Parameters (subset)
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `LVCompareExePath` | string | auto | Override LVCompare binary. |
| `LabVIEWExePath` | string | auto | Passed to LVCompare via `-lvpath`. |
| `BaseVi` / `HeadVi` | string | auto | Defaults to placeholder VIs under repo root. |
| `DiffArguments` | string[] | `@('-noattr','-nofp','-nofppos','-nobd','-nobdcosm')` | Extra LVCompare flags. |
| `TimeoutSeconds` | int | 60 | Process timeout. |
| `ExpectDiff` / `ExpectNoDiff` | switch | Off | Assert exit code 1 or 0. |
| `JsonLogPath` | string | `tests/results/_warmup/prime-lvcompare.ndjson` | NDJSON telemetry path. |
| `LeakCheck` | switch | Off | Run post-compare leak detection. |
| `LeakJsonPath` | string | `tests/results/_warmup/prime-lvcompare-leak.json` | Leak summary output. |

## Outputs
- NDJSON event log detailing binaries, args, exit code, durations, and diff status; optional leak JSON describing rogue processes.

## Related
- `tools/LabVIEWPidTracker.psm1`
- `tools/Detect-RogueLV.ps1`
- `docs/LVCOMPARE_LAB_PLAN.md`
