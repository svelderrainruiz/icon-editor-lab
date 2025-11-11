# Test-IconEditorPackage.Tests.ps1

**Path:** `tests/Test-IconEditorPackage.Tests.ps1`

## Synopsis
Ensures the package smoke helper reports status accurately.

## Description
- Runs `Test-IconEditorPackage.ps1` with fake VIPs to confirm pass/fail classification.
- Validates `icon-editor/package-smoke@v1` summary fields (vipCount, items[*].checks).
- Checks `-RequireVip` enforcement triggers failures when no artifacts are provided.
- Ensures error messages surface underlying VIP parsing issues for maintainers.

## Run
```powershell
pwsh -File Invoke-PesterTests.ps1 -TestsPath tests/Test-IconEditorPackage.Tests.ps1
```

## Tags
- Packaging
- Smoke

## Related
- `tools/icon-editor/Test-IconEditorPackage.ps1`
