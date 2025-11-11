# VipmDependencyHelpers.psm1

**Path:** `tools/icon-editor/VipmDependencyHelpers.psm1`

## Synopsis
Shared helper module for applying or listing VIPM dependencies across LabVIEW versions/bitness combinations.

## Description
- Resolves LabVIEW executables via `VendorTools.psm1`, ensures VIPM CLI readiness for each version (`Test-VipmCliReady`), and handles provider-specific extras (e.g., `vipm-gcli` requires `Applyvipc.vi` + display strings).
- `Install-VipmVipc` wraps `Get-VipmInvocation`/`Invoke-VipmProcess`, records telemetry under `tests/results/_agent/icon-editor/vipm-install`, and optionally logs installed package lists when using the classic provider.
- `Show-VipmDependencies` prints currently installed packages via `vipm list --installed` (display-only mode).
- Telemetry writers (`Write-VipmTelemetryLog`, `Write-VipmInstalledPackagesLog`) provide JSON history for readiness reviews and SRS traceability.

### Key Functions
| Function | Purpose |
| --- | --- |
| `Test-VipmCliReady` | Validates VIPM provider configuration for a LabVIEW version/bitness pair. |
| `Initialize-VipmTelemetry` | Returns/creates the telemetry directory in `tests/results/_agent/icon-editor/vipm-install`. |
| `Install-VipmVipc` | Applies the VIPC via the selected provider and logs telemetry + package info. |
| `Show-VipmDependencies` | Lists installed packages (classic provider only) and records telemetry. |

## Related
- `tools/Vipm.psm1`
- `tools/icon-editor/Invoke-VipmDependencies.ps1`
- `docs/LABVIEW_GATING.md`
