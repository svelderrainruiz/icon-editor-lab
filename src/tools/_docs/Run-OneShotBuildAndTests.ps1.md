# Run-OneShotBuildAndTests.ps1

**Path:** `tools/icon-editor/Run-OneShotBuildAndTests.ps1`

## Synopsis
One-button build pipeline: run VIPM CLI packaging and Icon Editor validation (unit tests + MissingInProject) in a single script for local or CI smoke checks.

## Description
- Sets headless LabVIEW environment variables and runs rogue detection before starting.
- Optionally reads a GH token from `-GhTokenPath` for repo sync operations.
- Steps:
  1. Invoke `tools/icon-editor/Invoke-VipmCliBuild.ps1` with the provided LabVIEW version/bitness inputs (skippable with `SkipSync`, `SkipVipcApply`, `SkipClose`).  
  2. Call `tools/icon-editor/Invoke-IconEditorBuild.ps1 -RunUnitTests -SkipPackaging`, writing outputs to `ResultsRootValidate`.  
  3. Stops the transcript and returns non-zero if either step fails.
- Useful for local “does everything still build?” loops without touching the full release pipeline.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `MinimumSupportedLVVersion` | int | `2021` | Lower bound for VIPM CLI / build gating. |
| `PackageMinimumSupportedLVVersion` | int | `2023` | Version embedded in the produced packages. |
| `PackageSupportedBitness` | int (32/64) | `64` | Bitness passed to the VIPM CLI build. |
| `SkipSync` / `SkipVipcApply` / `SkipClose` | string (`yes`/other) | — | When set to `yes`, skips the corresponding Invoke-VipmCliBuild stage. |
| `RepoSlug` | string | `LabVIEW-Community-CI-CD/labview-icon-editor` | Repo to sync during VIPM build. |
| `GhTokenPath` | string | — | File containing a PAT used for GitHub sync (optional). |
| `ResultsRootValidate` | string | `tests/results/_agent/icon-editor/local-validate` | Where the validation run stores artifacts. |

## Exit Codes
- `0` — VIPM CLI build and validation succeeded.
- `!=0` — Either VIPM CLI or Invoke-IconEditorBuild failed (see transcript).

## Related
- `tools/icon-editor/Invoke-VipmCliBuild.ps1`
- `tools/icon-editor/Invoke-IconEditorBuild.ps1`
- `tools/README.md`
