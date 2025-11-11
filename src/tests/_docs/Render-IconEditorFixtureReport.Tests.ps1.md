# Render-IconEditorFixtureReport.Tests.ps1

**Path:** `tests/Render-IconEditorFixtureReport.Tests.ps1`

## Synopsis
Validates the fixture report renderer and JSON schema.

## Description
- Feeds mock fixture VIPs into the descriptor to ensure `fixture-report.json` includes asset entries and hashes.
- Verifies overlay resources are merged and classified correctly.
- Checks schema upgrades preserve required fields for downstream manifest builders.
- Tests error handling when spec files or package folders are missing.

## Run
```powershell
pwsh -File Invoke-PesterTests.ps1 -TestsPath tests/Render-IconEditorFixtureReport.Tests.ps1
```

## Tags
- Fixtures
- Reports

## Related
- `tools/icon-editor/Render-IconEditorFixtureReport.ps1`
