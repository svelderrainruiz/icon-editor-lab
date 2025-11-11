# IconEditorMissingInProject.CompareOnly.Tests.ps1

**Path:** `tests/IconEditorMissingInProject.CompareOnly.Tests.ps1`

## Synopsis
Covers the compare-only flow for Missing In Project (MIP) CLI.

## Description
- Mimics compare-only invocations to ensure stage/compare/report steps run without dev-mode toggles.
- Verifies session-index and LVCompare capture JSON land under the expected results root.
- Confirms noise-profile and same-name hints propagate to the TestStand harness.
- Validates exit codes and output text when required VI paths or warmup settings are missing.

## Run
```powershell
pwsh -File Invoke-PesterTests.ps1 -TestsPath tests/IconEditorMissingInProject.CompareOnly.Tests.ps1
```

## Tags
- MIP
- Compare

## Related
- `tools/Invoke-MissingInProjectCLI.ps1`
