# Update-IconEditorFixtureReport.Tests.ps1

**Path:** `tests/Update-IconEditorFixtureReport.Tests.ps1`

## Synopsis
Tests the report updater that wraps Describe-IconEditorFixture.

## Description
- Verifies `Update-IconEditorFixtureReport.ps1` writes `fixture-report.json` plus optional manifest outputs.
- Checks overlay path handling, including failure paths when directories are invalid.
- Ensures deprecated switches (`-SkipDocUpdate`, `-CheckOnly`, `-NoSummary`) remain harmless no-ops.
- Confirms summary objects returned by the script include categorized fixture-only assets.

## Run
```powershell
pwsh -File Invoke-PesterTests.ps1 -TestsPath tests/Update-IconEditorFixtureReport.Tests.ps1
```

## Tags
- Fixtures
- Reports

## Related
- `tools/icon-editor/Update-IconEditorFixtureReport.ps1`
- `tools/icon-editor/Describe-IconEditorFixture.ps1`
