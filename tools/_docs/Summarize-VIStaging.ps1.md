# Summarize-VIStaging.ps1

**Path:** `tools/Summarize-VIStaging.ps1`

## Synopsis
Renders a Markdown (and optional JSON) summary of the `vi-staging-compare.json` output produced by `Run-StagedLVCompare.ps1`.

## Description
- Loads compare entries, optionally imports `VICategoryBuckets.psm1` to map change categories, and inspects compare reports to highlight included/suppressed sections, diff headings, and leak warnings.
- Produces totals (pairs, diff/match counts, category/bucket breakdowns, leak warnings) plus a Markdown table showing per-VI status, report links, flags, and diff details.
- `-MarkdownPath` and `-SummaryJsonPath` persist the outputs; `$GITHUB_OUTPUT` is updated with `markdown_path`, `summary_json`, and `compare_dir` for workflow use.

### Parameters
| Name | Type | Default |
| --- | --- | --- |
| `CompareJson` | string (required) | Path to `vi-staging-compare.json`. |
| `MarkdownPath` | string | - |
| `SummaryJsonPath` | string | - |

## Outputs
- PSCustomObject with `totals`, `pairs`, `markdown`, `compareDir`; optional Markdown/JSON files and GitHub outputs.

## Related
- `tools/Run-StagedLVCompare.ps1`
- `tools/Render-ViComparisonReport.ps1`
