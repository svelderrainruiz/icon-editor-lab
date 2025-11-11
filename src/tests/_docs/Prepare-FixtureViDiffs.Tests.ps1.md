# Prepare-FixtureViDiffs.Tests.ps1

**Path:** `tests/Prepare-FixtureViDiffs.Tests.ps1`

## Synopsis
Ensures fixture diff preparation script stages requests and metadata correctly.

## Description
- Builds temp fixture directories and verifies diff requests include absolute base/head paths.
- Checks optional filters (include/exclude categories, noise profiles) keep schema-valid output.
- Ensures scratch directories are cleaned when preparation succeeds or fails.
- Validates friendly errors when fixture artifacts or metadata files are missing.

## Run
```powershell
pwsh -File Invoke-PesterTests.ps1 -TestsPath tests/Prepare-FixtureViDiffs.Tests.ps1
```

## Tags
- Fixtures
- Diffs

## Related
- `tools/Prepare-FixtureViDiffs.ps1`
