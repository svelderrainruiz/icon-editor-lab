# Invoke-VIDiffSweep.Tests.ps1

**Path:** `tests/Invoke-VIDiffSweep.Tests.ps1`

## Synopsis
Tests the baseline VI diff sweep harness.

## Description
- Builds sweep plans over multiple VI pairs and confirms run directories/labels are deterministic.
- Verifies noise-profile, warmup, and timeout settings propagate to each compare invocation.
- Ensures summary JSON contains per-target exit codes plus aggregated status fields.
- Checks failure handling keeps processing remaining pairs unless cancellation is requested.

## Run
```powershell
pwsh -File Invoke-PesterTests.ps1 -TestsPath tests/Invoke-VIDiffSweep.Tests.ps1
```

## Tags
- VICompare
- Sweep

## Related
- `tools/Invoke-VIDiffSweep.ps1`
