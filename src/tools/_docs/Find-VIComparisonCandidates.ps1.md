# Find-VIComparisonCandidates.ps1

**Path:** `tools/compare/Find-VIComparisonCandidates.ps1`

## Synopsis
Scans git history between two refs and returns VI-related commits/files that should be queued for LVCompare, with optional filters and JSON output.

## Description
- Accepts a repo path (defaults to `vendor/icon-editor` under the current repo), verifies `BaseRef`/`HeadRef`, and inspects up to `-MaxCommits` (default 50).
- `-Kinds` currently supports `vi`, which maps to a set of LabVIEW extensions and include patterns. You can override file types with `-Extensions` or `-IncludePatterns`.
- `-IncludeMergeCommits` keeps merge commits; otherwise, the script focuses on the first-parent history.
- Produces a structured object with commit metadata (`commit`, `author`, `subject`, `files`) and aggregated counts, optionally written to `-OutputPath` as JSON.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `RepoPath` | string | `vendor/icon-editor` (relative) | Repository containing VIs to inspect. |
| `BaseRef` | string | *none* | Lower bound ref; when omitted, only `HeadRef` is analyzed. |
| `HeadRef` | string | `HEAD` | Upper bound ref. |
| `MaxCommits` | int | `50` | Limit for commits scanned. |
| `Kinds` | string[] | `vi` | Changeset kinds (controls extensions/patterns). |
| `IncludePatterns` / `Extensions` | string[] | - | Overrides for file filtering. |
| `IncludeMergeCommits` | switch | Off | Include merges in the scan. |
| `OutputPath` | string | - | When provided, writes the JSON report to disk. |

## Outputs
- JSON object with commit/file lists and summary counts (written to stdout or `-OutputPath`).

## Exit Codes
- `0` on success; non-zero when refs/repo path are invalid or git commands fail.

## Related
- `tools/Compare-VIHistory.ps1`
- `docs/LVCOMPARE_LAB_PLAN.md`
