# Invoke-IconEditorSnapshotFromRepo.Tests.ps1

**Path:** `tests/Invoke-IconEditorSnapshotFromRepo.Tests.ps1`

## Synopsis
Tests snapshot extraction from repository fixtures.

## Description
- Simulates pulling fixture definitions directly from git history and staging them into snapshot directories.
- Verifies snapshot metadata captures commit, branch, and overlay information.
- Ensures manifest/digest files are generated even when optional overlays are missing.
- Checks failure messages when repository paths or commits cannot be resolved.

## Run
```powershell
pwsh -File Invoke-PesterTests.ps1 -TestsPath tests/Invoke-IconEditorSnapshotFromRepo.Tests.ps1
```

## Tags
- Snapshots

## Related
- `tools/Invoke-IconEditorSnapshotFromRepo.ps1`
- `tools/Stage-IconEditorSnapshot.ps1`
