# Run-StagedLVCompare.ps1

**Path:** `tools/Run-StagedLVCompare.ps1`

## Synopsis
Executes LVCompare for every staged pair recorded by `Invoke-PRVIStaging` and writes comparison telemetry to `vi-staging-compare.json`.

## Description
- Consumes `vi-staging-results.json` (the output of `Invoke-PRVIStaging`), copies staged file paths, and calls `tools/Invoke-LVCompare.ps1` for each pair. Flags/noise profile can be overridden or replaced entirely.
- Records per-pair metadata (exit code, diff detected, report path, leak warnings) and updates the original results JSON plus a standalone compare summary.
- Emits aggregate counts (diff, match, skip, error, leak warnings) to `$GITHUB_OUTPUT` so workflows can gate on compare success.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `ResultsPath` | string (required) | - | Path to `vi-staging-results.json`. |
| `ArtifactsDir` | string (required) | - | Destination root for compare artifacts and `vi-staging-compare.json`. |
| `RenderReport` | switch | Off? (script default is on) | When set, request HTML reports from LVCompare. |
| `Flags` | string[] | env (`RUN_STAGED_LVCOMPARE_FLAGS`) | Custom LVCompare flags; `-ReplaceFlags` overrides defaults. |
| `NoiseProfile` | string (`full`,`legacy`) | `full` | Passed to `Invoke-LVCompare.ps1`. |
| `InvokeLVCompare` | scriptblock | - | Test hook to override the compare call. |

## Outputs
- Updates `ResultsPath` with compare info; writes `<ArtifactsDir>/vi-staging-compare.json`.
- GitHub output variables (`diff_count`, `match_count`, `skip_count`, `error_count`, `leak_warning_count`, etc.).

## Related
- `tools/Invoke-PRVIStaging.ps1`
- `tools/Invoke-LVCompare.ps1`
