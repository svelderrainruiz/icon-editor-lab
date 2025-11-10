# Parse-CompareExec.ps1

**Path:** `tools/Parse-CompareExec.ps1`

## Synopsis
Scans a directory for the latest `lvcompare-capture.json` or `compare-exec.json`, extracts key fields, and writes a normalized summary JSON plus Markdown snippet.

## Description
- Recursively searches `-SearchDir` for capture/exec JSON files, preferring capture data when available. Populates a payload with exit code, diff flag, duration, command line, CLI path, stdout/stderr/report artifacts, etc.
- Writes the normalized payload to `-OutJson` (default `compare-outcome.json`) and appends a short Markdown section (if running in GitHub Actions step summary) highlighting diff status and artifacts.
- Useful in CI summaries or ad-hoc investigations when you just need the latest compare outcome without digging through log directories.

### Parameters
| Name | Type | Default |
| --- | --- | --- |
| `SearchDir` | string | `.` |
| `OutJson` | string | `compare-outcome.json` |

## Outputs
- JSON payload describing compare outcome; optional Markdown appended to `$GITHUB_STEP_SUMMARY`.

## Related
- `tools/Render-ViComparisonReport.ps1`
- `docs/LVCOMPARE_LAB_PLAN.md`
