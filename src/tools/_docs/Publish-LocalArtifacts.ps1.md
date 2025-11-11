# Publish-LocalArtifacts.ps1

**Path:** `tools/icon-editor/Publish-LocalArtifacts.ps1`

## Synopsis
Packages VIP/PPL outputs from `tests/results/_agent/icon-editor/vipm-cli-build` into a timestamped zip and optionally uploads it to a GitHub release.

## Description
- Resolves the repo root, locates the `vipm-cli-build` folder created by one-shot builds, and gathers VIP, LVLIBP, `missing-items.json`, and `manifest.json` files.
- Compresses those artifacts into `iconeditor-local-artifacts-<timestamp>.zip` under `ArtifactsRoot`, printing the absolute path for session handoffs.
- When `-SkipUpload` is not set and `-GhTokenPath` points to a valid file, authenticates with `gh release` to create or update a prerelease (`ReleaseTag`/`ReleaseName` default to `local-build-<commit>-<timestamp>`) and uploads the zip.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `ArtifactsRoot` | string | `tests/results/_agent/icon-editor` | Root containing `vipm-cli-build`. |
| `GhTokenPath` | string | - | File that stores a PAT used by `gh release`. |
| `ReleaseTag` | string | auto (`local-build-<commit>-<ts>`) | Override tag name. |
| `ReleaseName` | string | auto (`Local build <commit> (<ts>)`) | Override display name. |
| `SkipUpload` | switch | Off | Package locally but skip the GitHub release upload. |

## Outputs
- `iconeditor-local-artifacts-<timestamp>.zip` in `ArtifactsRoot`.
- Optional GitHub release (created or updated) containing the zip.

## Exit Codes
- `0` – Zip created (and upload succeeded if requested).
- `!=0` – Missing artifacts/token or `gh release` failure.

## Related
- `tools/icon-editor/Invoke-OneShotTask.ps1`
- `tools/Post-IssueComment.ps1`
