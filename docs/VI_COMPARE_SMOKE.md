# VI Comparison Smoke Test

Use this recipe to produce a real LVCompare HTML report from the icon-editor
lab repo.

## Prerequisites

- LabVIEW 2025 (or any supported version) with LVCompare installed.
- G CLI and VI Analyzer tooling configured per `docs/LVCOMPARE_LAB_PLAN.md`.
- Sample base/head VIs. The defaults in `tools/Run-VICompareSample.ps1` point at
  `tests/fixtures/vi-compare/VI2/Base.vi` and `.../Head.vi`; adjust them if you
  want to compare different VIs.

## Steps

Default base/head VIs use the MissingInProject helper VIs under
`vendor/icon-editor/.github/actions/missing-in-project/`. Override `-BaseVI` and
`-HeadVI` if you want to diff other files.

```powershell
pwsh -File tools/Get-IconEditorLabTooling.ps1   # only needed if bundle isn't present
pwsh -File tools/Run-VICompareSample.ps1 `
  -LabVIEWPath 'C:\Program Files\National Instruments\LabVIEW 2025\LabVIEW.exe' `
  -OutputRoot tests/results/teststand-session `
  -Label vi-compare-smoke
```

The script wraps `tools/TestStand-CompareHarness.ps1` with sane defaults:

- Warmup skipped (we assume LVCompare already staged).
- `-RenderReport` enabled so an HTML report is generated.
- `-CloseLabVIEW` / `-CloseLVCompare` enabled to keep lab hosts clean.

When the run succeeds, look under
`tests/results/teststand-session/vi-compare-smoke/` for `compare-report.html`,
`compare-report.json`, and the LVCompare capture artifacts. Attach those outputs
in lab notes/PRs to prove the compare lane is healthy.

Pass `-DryRun` to the script if you only want to see the computed harness
command before executing it.
