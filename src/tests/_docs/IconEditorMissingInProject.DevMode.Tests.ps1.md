# IconEditorMissingInProject.DevMode.Tests.ps1

**Path:** `tests/IconEditorMissingInProject.DevMode.Tests.ps1`

## Synopsis
Tests dev-mode-aware MIP flows (policy toggles + compare).

## Description
- Ensures suite orchestration enables dev mode before compare and disables it afterward, even when compare fails.
- Checks telemetry attachments (session index, rogue sweep) reference the correct run IDs for each scenario.
- Validates error handling when policy files or LabVIEW paths are missing mid-run.
- Confirms cleanup removes temporary policy overrides so subsequent tests start clean.

## Run
```powershell
pwsh -File Invoke-PesterTests.ps1 -TestsPath tests/IconEditorMissingInProject.DevMode.Tests.ps1
```

## Tags
- MIP
- DevMode

## Related
- `tools/Invoke-MissingInProjectSuite.ps1`
