# Invoke-VipmDependencies.ps1

**Path:** `tools/icon-editor/Invoke-VipmDependencies.ps1`

## Synopsis
Applies the icon-editor `.vipc` dependencies (or lists them) through the configured VIPM provider after verifying versions/bitness requirements.

## Description
- Ensures VIPM is already running (CLI/g-cli providers rely on an existing VIPM session) and imports `tools/icon-editor/VipmDependencyHelpers.psm1` plus the repo’s `tools/Vipm.psm1`.
- Resolves the `.vipc` file located under `-RelativePath` (defaults to the repo root), validates LabVIEW versions/bitness combinations, and invokes either the `vipm-gcli` provider (install) or classic `vipm` provider (display only).
- Aggregates telemetry through `Initialize-VipmTelemetry`, then prints a per-version/per-bitness package list—useful when verifying ISO readiness for IELA-SRS-F-008 dependency coverage.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `MinimumSupportedLVVersion` | string | - | Required; install/display dependencies for the minimum supported LabVIEW version. |
| `VIP_LVVersion` | string | - | Optional second version (e.g., packaging target) to process after the minimum. |
| `SupportedBitness` | string[] | `@('64')` | Comma/space delimited values accepted; each must be `32` or `64`. |
| `RelativePath` | string | `.` (repo root) | Folder containing the `.vipc` file and VIPM modules. |
| `VIPCPath` | string | Auto-detect | Direct path to the `.vipc`; resolved automatically if only one exists under `RelativePath`. |
| `DisplayOnly` | switch | Off | Show dependency lists without invoking the installer (forces classic `vipm` provider). |

## Outputs
- Console summary that enumerates each LabVIEW version/bitness pair and the packages applied or listed.
- Telemetry stored beneath `tests/results/_agent/icon-editor/vipm` (via `Initialize-VipmTelemetry`) capturing provider, duration, and package hashes.

## Exit Codes
- `0` – Dependencies were applied or displayed successfully for every requested version/bitness.
- `!=0` – VIPM was not running, the `.vipc` file was missing/ambiguous, or the provider reported an error.

## Related
- `tools/icon-editor/VipmDependencyHelpers.psm1`
- `tools/Vipm/Invoke-ProviderComparison.ps1`
- `docs/LABVIEW_GATING.md`
