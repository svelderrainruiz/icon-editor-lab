# Documentation Quick Map

| Doc | Purpose |
| --- | --- |
| `../README.md` | Front door, quick-start commands, smoke test reference |
| `AGENTS.md` | Expectations for automation agents (first actions, bundle workflow, scenario checklist, hand-off notes) |
| `MIGRATION.md` | Phase plan for the carve-out plus remaining dependencies |
| `CONSUMPTION.md` | How downstream repos export/import the lab tooling bundle |
| `DEPENDENCIES.md` | Known references to `compare-vi-cli-action` that still need cleanup |
| `VI_COMPARE_SMOKE.md` | Step-by-step instructions for generating a real LVCompare HTML report |
| `LVCOMPARE_LAB_PLAN.md` | Detailed scenario matrix (1–6b), analyzer/compare requirements, artifact expectations |

## Scenario Cheat Sheet

Each scenario below refers to commands/scripts in this repo. Capture the listed
artifacts when validating a release.

1. **Baseline staging (same-name VIs)**  
   - Command: `pwsh -File tools/TestStand-CompareHarness.ps1 -Warmup skip -RenderReport:$false ...`  
   - Artifacts: `tests/results/teststand-session/session-index.json`, `compare/lvcompare-capture.json`.

2. **Auto CLI fallback**  
   - Warmup `detect` + `-SameNameHint`.  
   - Expect `session-index.compare.autoCli=true`; report JSON contains warmup warning.

3. **Missing capture guard**  
   - Run with `-SkipCliCapture` (or `COMPAREVI_NO_CLI_CAPTURE=1`).  
   - Report JSON mentions “capture skipped”.

4. **Noise profile toggle**  
   - Add `-NoiseProfile legacy`.  
   - Report summary notes `legacy`; capture JSON shows canonical `cliPath`.

5. **Dev-mode detector (error 1003)**  
   - Break dev mode, run `tools/icon-editor/Invoke-MissingInProjectSuite.ps1`.  
   - Analyzer pass 1 fails (1003), recovery runs, pass 2 succeeds. Attach analyzer log + retry metadata.

6a. **MIP (2023 x64) + LUnit lane**  
   - Run analyzer + `Run-MipLunit-2023x64`.  
   - Artifacts: analyzer JSON, MissingInProject report, LUnit integration summary.

6b. **Legacy MIP (2021 x64) + LUnit lane**  
   - Same as 6a with `ViAnalyzerVersion=2021`, `ViAnalyzerBitness=64`, `MIP_ALLOW_LEGACY=1`.  
   - Artifacts mirror 6a.

## Reliability Criteria

- `pwsh -File tools/icon-editor/Test-DevModeStability.ps1 -LabVIEWVersion 2021 -Bitness 64 -Iterations 3 -DevModeOperation Reliability`
- `tests/results/_agent/icon-editor/dev-mode-stability/latest-run.json` must show:
  - `status: succeeded`
  - `requirements.met: true`
  - `enable.devModeVerified: true` per iteration
  - No rogue PIDs in pre/post sweeps (`rogue.labview=[]`)

## VI Compare Smoke

Use `tools/Run-VICompareSample.ps1` (see `VI_COMPARE_SMOKE.md`). The command:

```powershell
pwsh -File tools/Run-VICompareSample.ps1 `
  -LabVIEWPath "C:\Program Files\National Instruments\LabVIEW 2025\LabVIEW.exe" `
  -Label vi-compare-smoke
```

produces `tests/results/teststand-session/vi-compare-smoke/compare-report.html`
and capture JSON. Attach these outputs when validating the compare workflow.
