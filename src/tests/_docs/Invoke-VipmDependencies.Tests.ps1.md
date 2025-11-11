# Invoke-VipmDependencies.Tests.ps1

**Path:** `tests/Invoke-VipmDependencies.Tests.ps1`

## Synopsis
Validates the VIPM dependency resolver script.

## Description
- Stubs VIPM CLI to ensure dependency manifests are parsed and install commands built correctly.
- Verifies results JSON lists packages, versions, and install outcomes in deterministic order.
- Checks error handling for missing VIPM executable or bad manifest entries.
- Ensures multi-package installs surface aggregated warnings for CI reviewers.

## Run
```powershell
pwsh -File Invoke-PesterTests.ps1 -TestsPath tests/Invoke-VipmDependencies.Tests.ps1
```

## Tags
- VIPM
- Dependencies

## Related
- `tools/Invoke-VipmDependencies.ps1`
- `tools/VendorTools.psm1`
