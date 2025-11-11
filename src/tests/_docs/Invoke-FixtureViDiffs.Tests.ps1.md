# Invoke-FixtureViDiffs.Tests.ps1

**Path:** `tests/Invoke-FixtureViDiffs.Tests.ps1`

## Synopsis
Tests the fixture VI diff request generator and execution harness.

## Description
- Creates synthetic diff requests to verify CLI argument construction and staging directories.
- Validates request schema (base/head, categories, metadata) before invoking the compare harness.
- Ensures summary JSON records per-request exit codes, reasons, and capture locations.
- Confirms helpful errors surface when request files are missing or reference nonexistent fixtures.

## Run
```powershell
pwsh -File Invoke-PesterTests.ps1 -TestsPath tests/Invoke-FixtureViDiffs.Tests.ps1
```

## Tags
- Fixtures
- Diffs

## Related
- `tools/Invoke-FixtureViDiffs.ps1`
