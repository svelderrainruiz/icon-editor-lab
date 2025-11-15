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

## Dev-Mode Workflow (agents)

- Before changing any dev-mode behavior, read:
  - `docs/DEV_MODE_WORKFLOW.md`
  - `src/tests/_docs/Enable-Disable-DevMode.Tests.ps1.md`
  - `src/tests/LvAddonDevMode.Tests.ps1` + `src/tests/IconEditorDevMode.Telemetry.Tests.ps1`
- When asked to “run” or “debug” dev mode, prefer:
  - VS Code tasks: `Local CI: Stage 25 DevMode (enable|disable|debug)`
  - Script: `tests/tools/Run-DevMode-Debug.ps1`
- On failures, do **not** edit vendor scripts first. Instead:
  - Inspect telemetry via `tests/tools/Show-LastDevModeRun.ps1` or VS Code task `Local CI: Show last DevMode run`.
  - Use `latest-run.json` under `tests/results/_agent/icon-editor/dev-mode-run/` as the source of truth.
- Preserve the telemetry contract:
  - Keep `schema`, `mode`, `operation`, `requestedVersions`, `requestedBitness`, `status`, `error`, `errorSummary`, `statePath` stable unless you also update tests + docs.
  - If you extend the schema, add/adjust tests in the telemetry suite and update `DEV_MODE_WORKFLOW.md`.
- Maintain path portability:
  - Always resolve via `$env:WORKSPACE_ROOT` / repo root; never hard-code `C:\...` in new dev-mode helpers.
  - Prefer `Join-Path -Path $RepoRoot -ChildPath 'rel/path'` over multi-segment `Join-Path` that might trigger `AdditionalChildPath` binding quirks.

## LvAddon dev-mode learning loop (x-cli)

- LvAddon dev mode uses x-cli as an optional simulation provider for LabVIEW/g-cli interactions.
- When asked to "refine" or "learn from" LvAddon dev-mode behavior:
  1. Run `tests/tools/Run-LvAddonLearningLoop.ps1` from the workspace root (uses WORKSPACE_ROOT when set).
  2. This script:
     - Summarizes x-cli `labview-devmode` invocations into `tests/results/_agent/icon-editor/xcli-devmode-summary.json`.
     - Summarizes VI History runs into `tests/results/_agent/vi-history/vi-history-run-summary.json` and families into `tests/results/_agent/vi-history/vi-history-family-summary.json`.
     - Summarizes VIPM installs into `tests/results/_agent/icon-editor/vipm-install-summary.json`.
     - Emits a learning snippet at `tests/results/_agent/icon-editor/xcli-learning-snippet.json`.
  3. Open the learning snippet and read `AgentInstructions` + `SampleRecords`:
     - Use these to propose or implement LvAddon dev-mode x-cli simulation scenarios (e.g., timeout/rogue patterns).
     - Incorporate VI History run/family summaries and VIPM install summaries to prioritize which scenarios, versions, or providers need better coverage or fixes.
     - Keep stderr messages compatible with existing telemetry patterns (`Error: ... Timed out waiting for app to connect to g-cli`, `Rogue LabVIEW ...`). 
  4. Apply scenario changes in `tools/x-cli-develop/src/XCli/Labview/LabviewDevmodeCommand.cs` and, if needed, extend tests under `src/tests` to verify the new behavior and updated summaries.
