<!-- markdownlint-disable-next-line MD041 -->
# LabVIEW Gating Reference

Scripts and knobs used to verify LabVIEW/LVCompare state on self-hosted runners.

## Guard helpers

| Script | Purpose |
| ------ | ------- |
| `tools/Ensure-LabVIEWClosed.ps1` | Stops LabVIEW before/after runs (respects cleanup env vars) |
| `tools/Close-LVCompare.ps1` | Graceful shutdown or forced kill with timeout |
| `tools/Detect-RogueLV.ps1` | Reports rogue LabVIEW/LVCompare processes (`-FailOnRogue` to fail) |

## Recommended environment defaults

| Variable | Default |
| -------- | ------- |
| `CLEAN_LV_BEFORE`, `CLEAN_LV_AFTER`, `CLEAN_LV_INCLUDE_COMPARE` | `true` |
| `LV_NO_ACTIVATE`, `LV_SUPPRESS_UI`, `LV_CURSOR_RESTORE` | `1` |
| `LV_IDLE_WAIT_SECONDS`, `LV_IDLE_MAX_WAIT_SECONDS` | `2`, `5` |

Set these in runner environment or workflow `env` blocks to minimize UI prompts.

## Usage example

```powershell
$env:LV_SUPPRESS_UI = '1'
$env:LV_NO_ACTIVATE = '1'
$env:LV_CURSOR_RESTORE = '1'
pwsh -File tools/Ensure-LabVIEWClosed.ps1
pwsh -File scripts/CompareVI.ps1 -Base VI1.vi -Head VI2.vi
```

## Troubleshooting

- Use `tools/Detect-RogueLV.ps1 -AppendToStepSummary` in workflows for visibility.
- Combine with session locks (`SESSION_LOCK_ENABLED=1`) to avoid concurrent CLI runners.

### MIP guardrails and legacy lanes

- The MissingInProject composite defaults to LabVIEW 2023 (64-bit). Override with
  `MIP_ALLOW_LEGACY=1` when you need to run 2021.
- Suite preflight can enforce expected versions: set `MIP_EXPECTED_LV_VER` and
  `MIP_EXPECTED_ARCH` and enable `MIP_ROGUE_PREFLIGHT=1` (default). Use
  `MIP_AUTOCLOSE_WRONG_LV=1` to auto-close non-expected instances.
- LVCompare HTML still requires LabVIEW 2025 x64; the preflight checks do not change that
  requirement.

## Developer tool quick reference

### Dev-mode lifecycle (IELA-SRS-F-001)

| Script | Purpose | Outputs/Artifacts |
| --- | --- | --- |
| `tools/icon-editor/Enable-DevMode.ps1` / `Disable-DevMode.ps1` | Wraps the dev-mode enable/disable CLI so LabVIEW INI + `dev-mode.txt` are mutated in a guarded fashion (rogue preflight, telemetry). | `tests/results/_agent/icon-editor/dev-mode-run/dev-mode-run-*.json` |
| `tools/icon-editor/Assert-DevModeState.ps1` | Verifies that every requested target currently includes/excludes the icon-editor path before continuing to analyzer or compare flows. | Telemetry appended to the dev-mode run JSON |
| `tools/icon-editor/Test-DevModeStability.ps1` | Runs N enable/disable loops with analyzer entrypoints to satisfy the reliability gate (3 consecutive passes). | `tests/results/_agent/icon-editor/dev-mode-stability/latest-run.json` |

### MissingInProject orchestration (IELA-SRS-F-008)

| Script | Purpose | Key References |
| --- | --- | --- |
| `tools/icon-editor/Invoke-MissingInProjectSuite.ps1` | Full suite runner: enforces VI Analyzer gate, launches the selected Pester suite, writes `_agent/reports/missing-in-project/<label>.json`, and emits `<label>/missing-in-project-session.json` describing the run. | Honors `MIP_EXPECTED_LV_*`, `MIP_SKIP_NEGATIVE`, `MIP_COMPARE_*` toggles |
| `tools/icon-editor/Run-MipLunit-2023x64.ps1` / `Run-MipLunit-2021x64.ps1` | Scenario 6a/6b orchestrators that call the suite above, then kick off `.github/actions/run-unit-tests`. Useful for PR labels or bundle validation. | `tests/results/_agent/reports/integration/*.json` |
| `tools/icon-editor/Invoke-VIAnalyzer.ps1` | Generic VI Analyzer driver used by MissingInProject and other lanes. Provides retry hooks when dev mode looks broken. | `tests/results/_agent/vi-analyzer/<label>/` |

### Snapshot + session index (IELA-SRS-INT-001)

| Script | Purpose | Outputs |
| --- | --- | --- |
| `tools/icon-editor/Stage-IconEditorSnapshot.ps1` | Mirrors the icon-editor source, applies overlay/fixtures, toggles dev mode for validation, and now writes `<stageRoot>/session-index.json` (`icon-editor/snapshot-session@v1`). | Snapshot session index + fixture manifest/report |
| `tools/Ensure-SessionIndex.ps1` | Creates a fallback `session-index.json` in `tests/results/` when Pester/job runners did not emit one (keeps workflows green). | `tests/results/session-index.json` |
| `tools/TestStand-CompareHarness.ps1` | Produces `tests/results/teststand-session/session-index.json` (`teststand-compare-session/v1`) for LVCompare smoke cases and Scenario 1/2/3. | `tests/results/teststand-session/session-index.json` |

### Compare/VI Analyzer utilities

| Script | Purpose | Notes |
| --- | --- | --- |
| `tools/Run-HeadlessCompare.ps1` | Canonical CLI-first LVCompare runner with warmup, noise profile, and capture controls. | Emits `compare-report.html`, `session-index.json`, `lvcompare-capture.json`. |
| `tools/report/Analyze-CompareReportImages.ps1` | Validates HTML compare reports and records missing/broken image stats (invoked automatically by MissingInProject when `-RequireCompareReport`). | Generates `compare-image-manifest.json` + summary JSON. |

## Related docs

- [`docs/ENVIRONMENT.md`](./ENVIRONMENT.md)
- [`docs/TROUBLESHOOTING.md`](./TROUBLESHOOTING.md)
- [`README.md`](../README.md#guardrails-for-missinginproject)
- [`docs/vi-analyzer/README.md`](./vi-analyzer/README.md)
