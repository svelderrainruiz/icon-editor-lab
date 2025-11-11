# LabVIEWCli.psm1

**Path:** `tools/LabVIEWCli.psm1`

## Synopsis
PowerShell module that standardizes LabVIEW CLI operations (VI Compare, VI Analyzer, Mass Compile, etc.) behind pluggable providers and shared telemetry/guardrails.

## Description
- Loads the operation catalog from `tools/providers/spec/operations.json` and auto-imports every provider module under `tools/providers/*/Provider.psm1` (e.g., `labviewcli`, `gcli`). Providers implement `Name()`, `ResolveBinaryPath()`, `Supports()`, and `BuildArgs()` so they can be registered via `Register-LVProvider`.
- `Invoke-LVOperation` normalizes parameters against the spec, resolves binaries (LabVIEWCLI, LVCompare, g-cli), applies environment guards (headless desktop, LVCompare noise profile), runs the external process, captures stdout/stderr/exit codes, and returns a telemetry object with timing + arguments.
- Convenience wrappers (`Invoke-LVCreateComparisonReport`, `Invoke-LVRunVIAnalyzer`, `Invoke-LVRunUnitTests`, `Invoke-LVMassCompile`, `Invoke-LVExecuteBuildSpec`, etc.) build the parameter hash for common workflows so other scripts do not need to know CLI syntax differences between providers.
- Integrates with `tools/LabVIEWPidTracker.psm1` to record LabVIEW process ownership in `tests/results/_cli/_agent/labview-pid.json`, making rogue-process sweeps deterministic across scenarios (baseline staging, dev-mode stability, VI Compare smoke).
- Emits structured events through `Write-LVOperationEvent` and returns PSCustomObject payloads callers can log or assert against (provider name, args, elapsedSeconds, stdout/stderr, `labviewPidTracker` block).

### Key Exports
| Function | Purpose |
| --- | --- |
| `Register-LVProvider`, `Get-LVProviders`, `Get-LVProviderByName`, `Get-LVOperationNames`, `Get-LVOperationSpec` | Manage provider registration and inspect the operations catalog. |
| `Invoke-LVOperation` | Core runner; resolves binaries, launches the provider, captures logs/exit code/timing, and appends PID-tracker data. |
| `Invoke-LVCreateComparisonReport` | Helper for LVCompare runs (base/head paths, report type/path, timeout override). |
| `Invoke-LVRunVI`, `Invoke-LVRunVIAnalyzer`, `Invoke-LVRunUnitTests`, `Invoke-LVMassCompile`, `Invoke-LVExecuteBuildSpec` | High-level wrappers used by icon-editor workflows, VI Analyzer gating, and VIPM bundles. |
| `Get-LabVIEWCliPidTracker`, `Add-LabVIEWCliPidTrackerToResult` | Surface tracker metadata to callers so they can log/attach it to session index artifacts. |

## Outputs
- Returns a PSCustomObject describing each invocation (`provider`, `binary`, `args`, `exitCode`, `elapsedSeconds`, `stdout`, `stderr`, `ok`, `labviewPidTracker`).
- Writes PID tracker JSON under `tests/results/_cli/_agent/labview-pid.json` whenever a provider is initialized, enabling dev-mode reliability checks (IELA-SRS-F-001/F-008).

## Related
- `tools/LabVIEWPidTracker.psm1`
- `tools/providers/*/Provider.psm1`
- `docs/LABVIEW_GATING.md`
