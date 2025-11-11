# Start-RunnerInvoker.ps1

**Path:** `tools/RunnerInvoker/Start-RunnerInvoker.ps1`

## Synopsis
Starts the local RunnerInvoker loop: spins up the named pipe, tracks LabVIEW PIDs, writes readiness/heartbeat files, and runs `Start-InvokerLoop` until the sentinel is removed.

## Description
- Initializes the `_invoker` results directory, writes `ready.json`, heartbeat, and PID files, and optionally touches a sentinel file used to control shutdown.
- Integrates with `LabVIEWPidTracker.psm1` to record LabVIEW processes started during invoker operations; writes `stopped.json` with final PID tracker context when the sentinel is removed.
- Launches `Start-InvokerLoop` (from `RunnerInvoker.psm1`) in a background job and monitors it until the sentinel disappears; also records console spawn telemetry (`console-spawns.ndjson`).

### Parameters
| Name | Type | Default |
| --- | --- | --- |
| `PipeName` | string | auto (`lvci.invoker.<runId>.<job>.<attempt>`) |
| `SentinelPath` | string | - | When deleted, stops the invoker loop. |
| `ResultsDir` | string | `tests/results/_invoker` |
| `ReadyFile` | string | `<ResultsDir>/_invoker/ready.json` |
| `StoppedFile` | string | `<ResultsDir>/_invoker/stopped.json` |
| `PidFile` | string | `<ResultsDir>/_invoker/pid.txt` |

## Outputs
- Creates/updates files under `<ResultsDir>/_invoker` to signal readiness, PID, heartbeat, and final stop metadata (including LabVIEW PID tracker info when available).

## Related
- `tools/RunnerInvoker/RunnerInvoker.psm1`
- `tools/RunnerInvoker/Wait-InvokerReady.ps1`
