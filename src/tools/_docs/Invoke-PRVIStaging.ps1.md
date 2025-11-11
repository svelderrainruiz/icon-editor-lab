# Invoke-PRVIStaging.ps1

**Path:** `tools/Invoke-PRVIStaging.ps1`

## Synopsis
Materializes the VI pairs described in a `vi-diff-manifest@v1` document and passes them to `tools/Stage-CompareInputs.ps1` (or a custom invoker) to prep LVCompare captures.

## Description
- Validates the manifest schema, eagerly loads JSON, and ignores entries missing either base or head paths.
- Optionally materializes the `base` side from a Git ref (`-BaseRef`) so renamed/removed files still have a file to compare against—snapshots are stored under `<WorkingRoot>/base-snapshots` or `vi-staging-base`.
- Calls `Stage-CompareInputs` (or `-StageInvoker`) for each viable pair, returning the staged metadata array or, when `-DryRun` is set, printing a formatted table of what would be staged.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `ManifestPath` | string (required) | - | Path to the `vi-diff-manifest@v1` JSON file. |
| `WorkingRoot` | string | - (Stage-CompareInputs default) | Parent folder forwarded to Stage-CompareInputs. |
| `DryRun` | switch | Off | Show the staging plan without copying files. |
| `StageInvoker` | scriptblock | - | Test hook that replaces the Stage-CompareInputs call. |
| `BaseRef` | string | - | Git ref used to materialize missing/identical base files into `base-snapshots`. |

## Outputs
- Returns a list of staged pair objects (change type, resolved base/head paths, staging folders, and optional base snapshot path).
- When `-DryRun` is provided, writes a table summarizing what would have been staged.

## Exit Codes
- `0` – Manifest processed; skipped entries are reported via verbose output.
- `!=0` – Manifest missing/invalid, or staging failed (exception propagated).

## Related
- `tools/Get-PRVIDiffManifest.ps1`
- `tools/Stage-CompareInputs.ps1`
- `tools/Invoke-PRVIHistory.ps1`
