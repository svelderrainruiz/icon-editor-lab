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
`vendor/labview-icon-editor/.github/actions/missing-in-project/`. Override `-BaseVI` and
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

## Local CI Automation (Ubuntu)

The Ubuntu and Windows local CI flows now cooperate:

1. Ubuntu stage 45 still knows how to create a dry-run payload (so the run never fails just because Windows hasn’t executed), but it first checks `out/vi-comparison/windows/<windows_stamp>/publish.json` for a publish summary that references the current Ubuntu run. When present, it copies the real LabVIEWCLI artifacts into `out/local-ci-ubuntu/<stamp>/vi-comparison/` and re-renders the Markdown + HTML reports.
2. Windows stage 37 (`local-ci/windows/stages/37-VICompare.ps1`) copies the imported Ubuntu payload into `out/vi-comparison/windows/<windows_stamp>`, runs LabVIEWCLI/TestStand (or a stub), and writes `publish.json` with `schema = 'vi-compare/publish@v1'`. That file captures which Ubuntu run the artifacts came from, so Ubuntu can pick the correct folder automatically.
3. `local-ci/ubuntu/config.yaml` now exposes:
   ```yaml
   vi_compare:
     enabled: true
     dry_run: true
     requests_template: ""          # optional path to custom vi-diff-requests.json
     windows_publish_root: out/vi-comparison/windows
   ```

This means you can quickly validate the LabVIEW CLI behavior on Windows (raw HTML, JSON, session-index) and then let Ubuntu re-render the reports (with all the dependency isolation it already had). If Windows hasn’t produced a publish summary yet, the stage falls back to the dry-run payload so the local CI run is still deterministic.

