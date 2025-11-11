# Analyze-CompareReportImages.ps1

**Path:** `tools/report/Analyze-CompareReportImages.ps1`

## Synopsis
Scan `compare-report.html` for `<img>` references, verify screenshots exist, and emit a manifest summarizing missing/duplicate/large/stale images.

## Description
- Parses the compare report HTML, collects all unique `<img src="...">` references, and resolves them relative to the report directory / run directory.
- For each image, records:
  - Size, last-write time, SHA256 hash, and inferred category (`bd`, `fp`, `attr`, `other`).
  - Flags for missing, zero-byte, large (>20 MB by default), or stale (>300 seconds older than report).  
- Builds aggregate counts (`references`, `existing`, `missing`, `zeroSize`, `largeSize`, `stale`, duplicate groups).
- Writes a manifest JSON (default `<RunDir>/compare-image-manifest.json` or `-OutManifestPath`) and sets `compare-image-summary.json` in the root for quick inspection.
- Used by MissingInProject `-RequireCompareReport` flows to enforce screenshot quality.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `ReportHtmlPath` | string (required) | — | Path to `compare-report.html`. |
| `RunDir` | string (required) | — | Directory containing compare artifacts. |
| `RootDir` | string (required) | — | Typically the results root (mirroring location). |
| `OutManifestPath` | string | `<RunDir>/compare-image-manifest.json` | Optional override for manifest path. |
| `StaleThresholdSeconds` | int | `300` | Age delta (in seconds) beyond which an image is considered stale. |
| `LargeThresholdBytes` | int | `20971520` (20 MB) | Size above which an image is flagged as large. |

## Exit Codes
- `0` — Manifest generated successfully (regardless of warnings).
- `!=0` — Report missing or unexpected parsing failure.

## Related
- `tools/TestStand-CompareHarness.ps1`
- `tools/report/New-LVCompareReport.ps1`
- `docs/LVCOMPARE_LAB_PLAN.md`
