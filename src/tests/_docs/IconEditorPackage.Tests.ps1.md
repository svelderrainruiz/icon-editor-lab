# IconEditorPackage.Tests.ps1

**Path:** `tests/IconEditorPackage.Tests.ps1`

## Synopsis
Validates VIP packaging metadata and manifest entries.

## Description
- Loads package manifest JSONs and asserts required VIP artifacts are present with matching digests.
- Checks version stamping (major/minor/patch/build/raw) aligns with simulated fixture versions.
- Ensures friendly validation errors surface when artifacts are missing or malformed.
- Confirms enum fields used by downstream smoke summaries remain stable.

## Run
```powershell
pwsh -File Invoke-PesterTests.ps1 -TestsPath tests/IconEditorPackage.Tests.ps1
```

## Tags
- Packaging
- VIPM

## Related
- `tools/icon-editor/Simulate-IconEditorBuild.ps1`
- `tools/icon-editor/Test-IconEditorPackage.ps1`
