# Invoke-IconEditorBuild.Tests.ps1

**Path:** `tests/Invoke-IconEditorBuild.Tests.ps1`

## Synopsis
Validates the top-level IconEditor build orchestrator.

## Description
- Stubs LabVIEW CLI and VIP packaging commands to ensure parameters flow into each stage.
- Ensures telemetry/report JSON is emitted for host-prep, build, and packaging sub-steps.
- Checks that failures short-circuit downstream operations while preserving diagnostic logs.
- Verifies returned paths (artifacts, transcripts) line up with the results directory layout.

## Run
```powershell
pwsh -File Invoke-PesterTests.ps1 -TestsPath tests/Invoke-IconEditorBuild.Tests.ps1
```

## Tags
- Build
- IconEditor

## Related
- `tools/Invoke-IconEditorBuild.ps1`
