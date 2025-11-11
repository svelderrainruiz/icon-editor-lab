# Invoke-IconEditorVipPackaging.Tests.ps1

**Path:** `tests/Invoke-IconEditorVipPackaging.Tests.ps1`

## Synopsis
Covers the VIP packaging wrapper that calls VIPM with Icon Editor artifacts.

## Description
- Builds command lines that reference VIPM executable, VIPB project files, and logging directories.
- Validates dependency resolution and ensures packaging request JSON matches expectations.
- Checks log parsing to detect VIPM failures and translate them into actionable errors.
- Confirms generated VIP paths are returned to callers for smoke-testing.

## Run
```powershell
pwsh -File Invoke-PesterTests.ps1 -TestsPath tests/Invoke-IconEditorVipPackaging.Tests.ps1
```

## Tags
- Packaging
- VIPM

## Related
- `tools/Invoke-IconEditorVipPackaging.ps1`
