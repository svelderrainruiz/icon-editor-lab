# Render-ViComparisonReport.ps1

**Path:** `tools/icon-editor/Render-ViComparisonReport.ps1`

## Synopsis
Convert a `lvcompare` summary JSON into a Markdown table summarizing per-VI compare results and artifact links.

## Description
- Reads the compare summary JSON produced by the dispatcher (`SummaryPath`), expects `counts` and `requests` arrays.
- Builds Markdown output documenting totals (same/different/skipped, dry-run, errors) and a per-VI table with status, messages, and artifact links (capture JSON, session index).
- Writes the Markdown to `<SummaryPath>.md` unless `-OutputPath` is provided.
- Used by LVCompare run reports to embed human-readable summaries (Scenario 1‑4).

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `SummaryPath` | string (required) | — | Path to the compare summary JSON (e.g., `pester-summary.json`). |
| `OutputPath` | string | `<SummaryPath>.md` | Destination for the rendered Markdown. |

## Exit Codes
- `0` — Report rendered successfully.
- `!=0` — Summary path missing or JSON parsing failure.

## Related
- `tools/TestStand-CompareHarness.ps1`
- `tools/Run-HeadlessCompare.ps1`
- `tools/report/New-LVCompareReport.ps1`
