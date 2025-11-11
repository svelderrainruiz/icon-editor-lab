# Render-ViComparisonReport.Tests.ps1

**Path:** `tests/Render-ViComparisonReport.Tests.ps1`

## Synopsis
Covers the VI comparison HTML renderer.

## Description
- Builds synthetic compare results to ensure HTML template rendering succeeds for both noise profiles.
- Validates capture JSON links (run id, CLI args, screenshot paths) embed into the report.
- Confirms re-running over the same data is idempotent and does not duplicate assets.
- Checks friendly warnings appear when capture data is incomplete.

## Run
```powershell
pwsh -File Invoke-PesterTests.ps1 -TestsPath tests/Render-ViComparisonReport.Tests.ps1
```

## Tags
- VICompare
- Reports

## Related
- `tools/Render-ViComparisonReport.ps1`
