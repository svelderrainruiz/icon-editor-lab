# Render-Report.Mock.ps1

**Path:** `tools/Render-Report.Mock.ps1`

## Synopsis
Generates a mock LVCompare HTML report by invoking `scripts/Render-CompareReport.ps1` with canned inputs.

## Description
- Useful for onboarding or testing report styling without running a real compare. The script points `Render-CompareReport.ps1` at fake command/exit-code/diff data and writes the output to `tests/results/compare-report.mock.html`.
- Can be run locally to preview CSS/JS changes or to validate that the renderer module loads successfully.

## Outputs
- `tests/results/compare-report.mock.html`
- Console message indicating the mock file location.

## Related
- `scripts/Render-CompareReport.ps1`
- `tools/Render-ViComparisonReport.ps1`
