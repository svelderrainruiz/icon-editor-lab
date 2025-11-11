# Get-PRVIDiffManifest.ps1

**Path:** `tools/Get-PRVIDiffManifest.ps1`

## Synopsis
Builds a `vi-diff-manifest@v1` JSON describing VI changes between two git refs, with optional ignore patterns or dry-run summaries.

## Description
- Runs `git diff --name-status` between `-BaseRef` and `-HeadRef`, filters files by VI extensions, and classifies each entry as `added`, `modified`, `deleted`, or `renamed` (capturing rename scores when available).
- `-IgnorePattern` accepts wildcard globs applied to both base/head paths.
- `-DryRun` prints a table instead of JSON so you can preview the manifest before saving.
- By default, writes the JSON to stdout; `-OutputPath` saves it to disk (directories auto-created).

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `BaseRef` | string (required) | - | Baseline commit/branch/tag. |
| `HeadRef` | string (required) | - | Target commit/branch/tag with changes. |
| `OutputPath` | string | *stdout* | Destination for manifest JSON. |
| `IgnorePattern` | string[] | *none* | Wildcard globs to skip (e.g., `tests/*`). |
| `DryRun` | switch | Off | Print human-readable summary instead of JSON. |

## Exit Codes
- `0` when manifest/dry-run completes.
- Non-zero when git commands fail or refs are invalid.

## Related
- `tools/compare/Find-VIComparisonCandidates.ps1`
- `docs/LVCOMPARE_LAB_PLAN.md`
