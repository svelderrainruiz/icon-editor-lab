# Invoke-MissingInProjectCLI.Tests.ps1

**Path:** `tests/Invoke-MissingInProjectCLI.Tests.ps1`

## Synopsis
Unit-tests the CLI wrapper for Missing In Project runs.

## Description
- Ensures required arguments (suite label, results root, VI paths) are validated with clear messages.
- Verifies optional switches (noise profile, same-name hints, skip warmup) toggle the underlying harness.
- Confirms session-index and capture JSON paths are emitted exactly once per run.
- Checks non-zero exit codes map to the appropriate failure stage for gating logic.

## Run
```powershell
pwsh -File Invoke-PesterTests.ps1 -TestsPath tests/Invoke-MissingInProjectCLI.Tests.ps1
```

## Tags
- MIP
- CLI

## Related
- `tools/Invoke-MissingInProjectCLI.ps1`
