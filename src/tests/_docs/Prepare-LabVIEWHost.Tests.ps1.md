# Prepare-LabVIEWHost.Tests.ps1

**Path:** `tests/Prepare-LabVIEWHost.Tests.ps1`

## Synopsis
Tests the host-prep script that closes rogue LabVIEW/LVCompare sessions.

## Description
- Simulates running hosts with fake LabVIEW processes and ensures cleanup commands run under ShouldProcess.
- Validates skip flags and `-Force` behavior prevent unnecessary termination.
- Ensures telemetry output captures processes inspected, closed, or ignored.
- Confirms exit codes propagate so CI can gate on failed cleanup.

## Run
```powershell
pwsh -File Invoke-PesterTests.ps1 -TestsPath tests/Prepare-LabVIEWHost.Tests.ps1
```

## Tags
- HostPrep
- LabVIEW

## Related
- `tools/Prepare-LabVIEWHost.ps1`
- `tools/Detect-RogueLV.ps1`
