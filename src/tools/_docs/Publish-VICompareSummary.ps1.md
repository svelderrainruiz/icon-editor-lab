# Publish-VICompareSummary.ps1

**Path:** `tools/Publish-VICompareSummary.ps1`

## Synopsis
Builds a stakeholder-friendly VI Compare summary from a manifest and posts it as a GitHub issue/PR comment (or prints the Markdown in dry-run mode).

## Description
- Loads the `pr-vi-history-summary@v1` manifest produced by `Invoke-PRVIHistory.ps1`, derives aggregate stats (processed comparisons, diffs, missing files), and merges optional `ModeSummaryJson` data to describe attribute coverage for each compare mode.
- Resolves paths to the Markdown/HTML history reports so the posted comment can link directly to artifacts generated under `tests/results/pr-vi-history/...`.
- Requires a GitHub token (GH_TOKEN/GITHUB_TOKEN or `-GitHubToken`) and repository slug to call the REST API. When `-DryRun` is set, it prints the formatted Markdown instead of posting.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `ManifestPath` | string (required) | - | Path to `vi-history-summary.json`. |
| `ModeSummaryJson` | string (required) | - | JSON string summarizing each compare mode (often produced by CI jobs). |
| `HistoryReportPath` / `HistoryReportHtmlPath` | string | - | Optional links that will be embedded in the comment. |
| `Issue` | string (required) | - | GitHub issue/PR number to comment on. |
| `Repository` | string | `$env:GITHUB_REPOSITORY` | Owner/repo slug for the REST call. |
| `GitHubToken` | string | from env | Token used for the API request. |
| `DryRun` | switch | Off | Output Markdown locally without posting. |

## Outputs
- Posts a Markdown comment summarizing compare coverage (modes, attributes, diff counts). On `-DryRun`, writes the body to stdout.

## Exit Codes
- `0` – Manifest parsed and comment posted (or dry-run output succeeded).
- `!=0` – Missing inputs or HTTP failure (script throws with details).

## Related
- `tools/Invoke-PRVIHistory.ps1`
- `tools/Post-IssueComment.ps1`
