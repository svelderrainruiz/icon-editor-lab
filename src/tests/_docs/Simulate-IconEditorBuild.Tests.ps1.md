# Simulate-IconEditorBuild.Tests.ps1

**Path:** `tests/Simulate-IconEditorBuild.Tests.ps1`

## Synopsis
Validates the simulated build pipeline for Icon Editor fixtures.

## Description
- Exercises fixture VIP extraction, resource overlay, and manifest JSON generation.
- Confirms lvlibp artifacts are deduplicated and recorded with sha256 + size metadata.
- Validates optional VI diff requests (`-VipDiffOutputDir`) are produced when requested.
- Tests cleanup toggles (`-KeepExtract`, `-SkipResourceOverlay`) to ensure they behave as documented.

## Run
```powershell
pwsh -File Invoke-PesterTests.ps1 -TestsPath tests/Simulate-IconEditorBuild.Tests.ps1
```

## Tags
- Build
- Simulation

## Related
- `tools/icon-editor/Simulate-IconEditorBuild.ps1`
