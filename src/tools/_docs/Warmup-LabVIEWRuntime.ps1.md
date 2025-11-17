# Warmup-LabVIEWRuntime.ps1

**Path:** `tools/Warmup-LabVIEWRuntime.ps1`

## Synopsis
Start (and optionally stop) LabVIEW to “warm up” the runtime, emitting telemetry and process snapshots so downstream compares run faster/stabler on self-hosted runners.

## Description
- Resolves `LabVIEWPath`/version/bitness from CLI arguments or environment variables (`LABVIEW_PATH`, `MINIMUM_SUPPORTED_LV_VERSION`, etc.).
- Launches LabVIEW with UI-suppression flags, waits for a heartbeat (`TimeoutSeconds`, `IdleWaitSeconds`), and records NDJSON events (`warmup-labview-v1`) plus optional process snapshots (`labview-process-snapshot/v1`). Direct `LabVIEW.exe` launches are now guarded: the script will throw if asked to start LabVIEW directly, and callers are expected to route operations through `tools/codex/Invoke-LabVIEWOperation.ps1` and the appropriate x-cli workflow instead.
- Supports dry-run mode, `StopAfterWarmup`, and `KillOnTimeout` to take down LabVIEW after warmup (guardrail step from `docs/LABVIEW_GATING.md`).

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `LabVIEWPath` | string | Auto derived | Explicit path to `LabVIEW.exe`. |
| `MinimumSupportedLVVersion` | string | Auto derived (`2025`) | Used when LabVIEWPath is omitted. |
| `SupportedBitness` | string (`32`,`64`) | Auto derived (`64`) | Bitness to target. |
| `TimeoutSeconds` | int | `30` | Wait for LabVIEW to launch. |
| `IdleWaitSeconds` | int | `2` | Additional idle delay after launch. |
| `KeepLabVIEW` | switch | Off | Keep LabVIEW running (default), or use `-StopAfterWarmup` to close it. |
| `StopAfterWarmup` | switch | Off | Close LabVIEW at the end of warmup. |
| `JsonLogPath` | string | `tests/results/_warmup/labview-runtime.ndjson` | NDJSON telemetry output. |
| `SnapshotPath` | string | `tests/results/_warmup/labview-processes.json` | Snapshot of LabVIEW processes. |
| `SkipSnapshot` | switch | Off | Disable snapshot emission. |
| `DryRun` | switch | Off | Log warmup plan without launching LabVIEW. |
| `KillOnTimeout` | switch | Off | Force-close LabVIEW if stop is requested and the process lingers. |

## Exit Codes
- `0` — Warmup succeeded (or dry-run completed).
- `!=0` — LabVIEW failed to start or stop within the configured timeout.

## Related
- `tools/Run-HeadlessCompare.ps1`
- `tools/Close-LabVIEW.ps1`
- `docs/LABVIEW_GATING.md`
