# Agent Handbook (icon-editor-lab)

## Mission

- Maintain the icon-editor lab tooling (dev-mode scripts, VI Analyzer configs, VIPM helpers).
- Produce bundle exports for `compare-vi-cli-action` via `tools/Export-LabTooling.ps1`.
- Verify the scenario matrix (1–6b) and reliability gates before publishing a bundle/PR.

## First Actions

1. `pwsh -File Invoke-PesterTests.ps1` (core suites) or targeted `-TestsPath` runs (Enable/Disable dev mode, telemetry, stability, VI Analyzer).
2. If tests need the imported bundle, run `pwsh -File tools/Get-IconEditorLabTooling.ps1` (defaults to `vendor/icon-editor-lab/bundle/`).
3. Review `docs/MIGRATION.md` + `docs/CONSUMPTION.md` for current expectations.

## Bundle Workflow

| Step | Command | Notes |
| --- | --- | --- |
| Export | `pwsh -File tools/Export-LabTooling.ps1 -Destination artifacts/icon-editor-lab-tooling.zip -Force` | Run before tagging a release. |
| Import (consumer) | `pwsh -File tools/Get-IconEditorLabTooling.ps1 -BundlePath <zip>` | Extracts to `vendor/icon-editor-lab/bundle/`. |
| Resolver | `Resolve-IconEditorLabPath.ps1` | Returns bundle root; scripts should prefer this path. |

## Scenario Checklist

1. **Baseline staging**: Stage same-name VIs, run harness (`Warmup skip`). Artifacts: `session-index.json`, `compare/lvcompare-capture.json`, no warnings.
2. **Auto CLI fallback**: Warmup `detect` + `-SameNameHint`. Expect `session-index.compare.autoCli=true` and warmup warning in report.
3. **Missing capture guard**: Run with `-SkipCliCapture` (or `COMPAREVI_NO_CLI_CAPTURE=1`). Report JSON must state "capture skipped".
4. **Noise profile**: Run with `-NoiseProfile legacy`. Report summary lists `legacy`; capture JSON shows canonical `cliPath`.
5. **Dev-mode detector**: Intentionally break dev mode. Analyzer pass 1 fails (1003), recovery closes LV + re-enables token, pass 2 succeeds. Attach analyzer log + retry metadata.
6a. **MIP 2023 x64 + LUnit**: Analyzer succeeds, compare report HTML present, LUnit summary JSON recorded.
6b. **MIP 2021 x64 + LUnit**: Same as 6a with `ViAnalyzerVersion=2021`, `ViAnalyzerBitness=64`, `MIP_ALLOW_LEGACY=1`.

## Reliability (dev-mode open/close)

- `pwsh -File tools/icon-editor/Test-DevModeStability.ps1 -LabVIEWVersion 2021 -Bitness 64 -Iterations 3 -DevModeOperation Reliability`
- Need **3 consecutive** verified iterations. Check `tests/results/_agent/icon-editor/dev-mode-stability/latest-run.json` for `requirements.met=true`.
- Rogue sweeps (pre/post) must show `rogue.labview=[]`.

## VI Compare Smoke

- `pwsh -File tools/Run-VICompareSample.ps1 -LabVIEWPath "C:\Program Files\National Instruments\LabVIEW 2025\LabVIEW.exe" -Label vi-compare-smoke`
- Produces `tests/results/teststand-session/vi-compare-smoke/compare-report.html`.
- Attach HTML + capture JSON for PRs.

## Telemetry Targets

- `tests/results/_agent/vi-analyzer/<label>/vi-analyzer-report.txt/json`
- `tests/results/_agent/icon-editor/dev-mode-run/dev-mode-run-*.json`
- `tests/results/_agent/icon-editor/dev-mode-stability/latest-run.json`
- `_agent/reports/integration/<label>.json` for combined analyzer + LUnit runs.

## Docs to Read

- `docs/LVCOMPARE_LAB_PLAN.md` – scenario matrix/details.
- `docs/VI_COMPARE_SMOKE.md` – smoke instructions.
- `docs/ICON_EDITOR_LAB_MIGRATION.md` – migration plan + success criteria.
- `docs/CONSUMPTION.md` – how the bundle is consumed downstream.

## Handoff Expectations

- Sync bundle export/import status.
- Note which scenarios/runs are complete vs pending (link to artifacts).
- Record outstanding CI failures or rogue PID findings.
- Ensure `ICON_EDITOR_LAB_ROOT` is set in the environment when running scripts from the bundle (or note if you fell back to legacy paths).
