# Stage-IconEditorSnapshot.Tests.ps1

**Path:** `tests/Stage-IconEditorSnapshot.Tests.ps1`

## Synopsis
Tests snapshot staging from fixture folders.

## Description
- Builds stage directories and ensures metadata (version, digest, commit info) is written alongside artifacts.
- Verifies duplicate staging attempts either overwrite correctly or emit warnings based on parameters.
- Checks manifest output matches schema expected by downstream pipelines.
- Ensures failure paths clean up partial staging directories.

## Run
```powershell
pwsh -File Invoke-PesterTests.ps1 -TestsPath tests/Stage-IconEditorSnapshot.Tests.ps1
```

## Tags
- Snapshots
- IconEditor

## Related
- `tools/Stage-IconEditorSnapshot.ps1`
