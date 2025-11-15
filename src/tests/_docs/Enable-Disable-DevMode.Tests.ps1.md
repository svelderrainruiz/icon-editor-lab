# Enable-Disable-DevMode.Tests.ps1

**Path:** `tests/Enable-Disable-DevMode.Tests.ps1`

## Synopsis
Validates the Enable/Disable dev mode scripts toggle policy markers safely.

## Description
- Invokes `Enable-DevMode.ps1` / `Disable-DevMode.ps1` with stub LabVIEWCLI paths to ensure state files are created and removed.
- Exhausts ShouldProcess, `-Force`, and `-WhatIf` flows so scripts never modify policy markers when confirmation is skipped.
- Confirms helper env vars (`ICON_EDITOR_DEV_MODE_POLICY_PATH`, `ICON_EDITOR_SKIP_WAIT_FOR_LABVIEW_EXIT`, `SKIP_ROGUE_LV_DETECTION`) are honored and reset between tests.
- Verifies temporary CLI shims and env overrides are cleaned up after each scenario to avoid leaking state into later suites.

## Run
```powershell
pwsh -File Invoke-PesterTests.ps1 -TestsPath tests/Enable-Disable-DevMode.Tests.ps1
```

## Tags
- IconEditor
- DevMode
- Scripts

## Related
- `tools/icon-editor/Enable-DevMode.ps1`
- `tools/icon-editor/Disable-DevMode.ps1`
 - `tests/tools/Run-DevMode-Debug.ps1` (VS Code tasks: Local CI Stage 25 DevMode enable/disable/debug)
 - `tests/tools/Show-LastDevModeRun.ps1` (VS Code task: Local CI Show last DevMode run)
