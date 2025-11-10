# Prepare-OverlayFromRepo.ps1

**Path:** `tools/icon-editor/Prepare-OverlayFromRepo.ps1`

## Synopsis
Materializes an overlay directory containing only the VI/CTL/LVClass files that changed between `BaseRef` and `HeadRef`.

## Description
- Validates the provided repo path (`RepoPath`), resolves both refs via `git rev-parse`, and enumerates changed files (`git diff --name-only --diff-filter=ACMRT` plus optional include patterns).
- Copies only matching extensions (default `.vi`, `.ctl`, `.lvclass`, `.lvlib`) from the head commit into `OverlayRoot`, recreating the original directory structure.
- Skips unchanged files by comparing base/head blobs byte-for-byte; requires `-Force` to overwrite existing overlays.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `RepoPath` | string | current dir | Icon-editor repo root containing the git history. |
| `BaseRef` | string (required) | - | Baseline commit/ref. |
| `HeadRef` | string | `HEAD` | Target commit/ref. |
| `OverlayRoot` | string (required) | - | Destination directory; recreated when `-Force` is set. |
| `IncludePatterns` | string[] | `@('resource/','Test/')` | Path filters appended to the git diff command. |
| `Extensions` | string[] | `@('.vi','.ctl','.lvclass','.lvlib')` | File types to copy. |
| `Force` | switch | Off | Remove any existing overlay directory before populating. |

## Outputs
- Returns a PSCustomObject with `overlayRoot`, `files`, and ref metadata; overlay directory contains the copied files ready for staging/compare.

## Related
- `tools/icon-editor/Prepare-OverlayFromVip.ps1`
- `tools/icon-editor/Stage-IconEditorSnapshot.ps1`
