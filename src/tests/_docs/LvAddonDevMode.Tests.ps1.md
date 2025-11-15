# LvAddonDevMode.Tests.ps1

**Path:** `tests/LvAddonDevMode.Tests.ps1`

## Synopsis
Unit-tests the LvAddon dev-mode state helpers in `IconEditorDevMode.psm1`.

## Description
- Exercises `Get-IconEditorDevModeState`/`Set-IconEditorDevModeState` against fresh TestDrive repos to verify default path creation.
- Validates schema, version fields, and error handling when corrupt JSON markers are encountered.
- Ensures repeated enable/disable calls remain idempotent and always return consistent metadata (source, actor, timestamps).
- Confirms helper functions respect rogue-detection env toggles and propagate warnings for missing policy markers.

## Run
```powershell
pwsh -File Invoke-PesterTests.ps1 -TestsPath tests/LvAddonDevMode.Tests.ps1
```

## Tags
- LvAddon
- DevMode

## Related
- `tools/icon-editor/IconEditorDevMode.psm1`
