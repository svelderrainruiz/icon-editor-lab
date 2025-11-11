# IconEditorDevMode.Integration.Tests.ps1

**Path:** `tests/IconEditorDevMode.Integration.Tests.ps1`

## Synopsis
Integration tests for the dev-mode enable/disable flows with real policy files.

## Description
- Runs enable -> work -> disable sequences end-to-end and validates marker files appear in the repo root.
- Simulates rogue LabVIEW instances to ensure cleanup code waits for safe shutdown and logs PID data.
- Verifies telemetry breadcrumbs (summary text, JSON attachments) align with the operations performed.
- Checks failure paths (e.g., missing policy path, forced exit) leave dev-mode disabled and emit actionable errors.

## Run
```powershell
pwsh -File Invoke-PesterTests.ps1 -TestsPath tests/IconEditorDevMode.Integration.Tests.ps1
```

## Tags
- IconEditor
- DevMode
- Integration

## Related
- `tools/icon-editor/Enable-DevMode.ps1`
- `tools/icon-editor/Disable-DevMode.ps1`
- `tools/icon-editor/IconEditorDevMode.psm1`
