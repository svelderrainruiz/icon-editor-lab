# Invoke-OneShotTask.ps1

**Path:** `tools/icon-editor/Invoke-OneShotTask.ps1`

## Synopsis
Replicates the VS Code “IconEditor: One-shot” tasks from the command line.

## Description
- Wraps `tools/icon-editor/Run-OneShotBuildAndTests.ps1` with the same presets that the VS Code tasks use (`Fast` skips repo sync/VIPC apply; `Robust` performs the full bootstrap).
- Handles validation knobs (`MinimumSupportedLVVersion`, `PackageMinimumSupportedLVVersion`, `PackageSupportedBitness`, custom results root) so local runs match CI requirements for IELA-SRS-F-001 dev-mode coverage.
- Artifact publishing now routes through the Stage → Validate → QA → Upload helpers (see `tools/Stage-XCliArtifact.ps1`, etc.); the legacy `-PublishArtifacts` flag is retired and will throw if supplied.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Preset` | string (`Fast`,`Robust`) | `Fast` | Chooses which VS Code task shape to mirror. |
| `MinimumSupportedLVVersion` | int | `2021` | Forwarded to Run-OneShotBuildAndTests. |
| `PackageMinimumSupportedLVVersion` | int | `2023` | Ensures artifacts target the right LabVIEW version. |
| `PackageSupportedBitness` | int (`32`,`64`) | `64` | Bitness for package build validation. |
| `GhTokenPath` | string | `C:\github_token.txt` | Token file consumed by downstream scripts (e.g., publishing). |
| `RepoSlug` | string | `LabVIEW-Community-CI-CD/labview-icon-editor` | Passed to Sync helpers when the working copy needs to be refreshed. |
| `ResultsRootValidate` | string | `tests/results/_agent/icon-editor/local-validate` | Where the validation run drops logs/reports. |
| `PublishArtifacts` | switch | Off (retired) | Deprecated. Using it throws and instructs callers to run the Stage/Test/Promote/Upload helpers manually. |
| `SkipUpload` | switch | Off (retired) | Deprecated together with `-PublishArtifacts`. |

## Outputs
- Replays whatever `Run-OneShotBuildAndTests.ps1` generates (VIPs, PPLs, JSON metadata) beneath `ResultsRootValidate` and `artifacts/`.
- Console banner describing the preset and LabVIEW targets.

## Exit Codes
- `0` – One-shot completed (and publish, if enabled, succeeded).
- `!=0` – Underlying helper failed; the script throws after surfacing the failing step.

## Related
- `tools/icon-editor/Run-OneShotBuildAndTests.ps1`
- `tools/Stage-XCliArtifact.ps1`
- `tools/Test-XCliReleaseAsset.ps1`
- `tools/Promote-XCliArtifact.ps1`
- `tools/Upload-XCliArtifact.ps1`
- `docs/LABVIEW_GATING.md`
