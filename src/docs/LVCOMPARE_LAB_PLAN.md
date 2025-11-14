# LVCompare Lab Run Plan (#595)

## Objective

Verify the new LVCompare staging plus reporting flow end-to-end on hardware so we can land the
remaining #595 work with real telemetry (reports under `tests/results/_agent/reports/lvcompare/`
plus session-index artifacts).

## Preconditions

1. Lab runner has the prepared VI fixtures checked in (`VI2.vi`, `tmp-commit-236ffab\VI2.vi`).
2. `tools/icon-editor/Prepare-LabVIEWHost.ps1` has been executed for the target LabVIEW
   version/bitness (see host-prep instructions in the developer guide).
3. Environment variables:
   - `LV_SUPPRESS_UI=1`, `LV_NO_ACTIVATE=1`, `LV_CURSOR_RESTORE=1`.
   - `COMPAREVI_REPORTS_ROOT` cleared (default repo root) unless we need to isolate run output.
4. Ensure no rogue LabVIEW/LVCompare processes are running
   (`pwsh -File tools/Detect-RogueLV.ps1 -FailOnRogue`).
5. Install the **VI Analyzer Toolkit** for each LabVIEW version/bitness used in the scenarios
   below (2023/64 for scenario 6a, 2021/64 for scenario 6b). LabVIEWCLI returns error `-350053`
   when the toolkit is missing.

### Guardrails & environment toggles

- Scenario 6a is locked to **LabVIEW 2023 x64**. The helper scripts export
  `MIP_EXPECTED_LV_VER=2023`, `MIP_EXPECTED_ARCH=64`, and `MIP_ROGUE_PREFLIGHT=1` so rogue
  detection blocks the run if stray LabVIEW instances are present.
- Pass `-AutoCloseWrongLV` (or set `MIP_AUTOCLOSE_WRONG_LV=1`) to terminate non-2023 LabVIEW
  processes automatically before the analyzer runs.
- Legacy LabVIEW 2021 x64 is opt-in. Set `MIP_ALLOW_LEGACY=1` and use the legacy runner only
  when you need to verify that toolchain; make sure the VI Analyzer Toolkit and LabVIEW 2021 x64
  installs are healthy first.
- Each orchestrator writes an integration summary under
  `tests/results/_agent/reports/integration/<label>.json` capturing toolkit/g-cli checks, rogue
  detection, analyzer status, and the final LUnit totals. Inspect the summary before filing lab
  issues.

## Scenario Matrix

| Scenario | Inputs | Harness Flags | Expected Outputs |
| --- | --- | --- | --- |
| 1. Baseline staging (same-name VIs) | `VI2.vi` pair staged via Stage-CompareInputs | `-Warmup skip -RenderReport:$false -AllowSameLeaf` | `tests/results/teststand-session/session-index.json`; `lvcompare-capture.json` under `compare/`; no warnings |
| 2. Auto CLI fallback | Synthetic `Sample.vi` pair (different dirs, same leaf) | `-Warmup detect -RenderReport -SameNameHint` | `session-index.json` with `compare.autoCli=true`; `reports/lvcompare/lvcompare-*.json` referencing warning (missing warmup) |
| 3. Missing capture guard | Run harness with `-SkipCliCapture` (or `COMPAREVI_NO_CLI_CAPTURE=1`) | `-RenderReport -SkipCliCapture` | Report JSON should include warnings about missing capture and `compare-report.html`, plus "CLI capture skipped" |
| 4. Noise profile toggle | Real VI pair requiring `-NoiseProfile legacy` | `-NoiseProfile legacy -RenderReport` | Report summary should record noise profile, capture shows `cliPath` as canonical location |
| 5. Dev-mode detector (error 1003) | Break dev mode intentionally (unset token), then launch MissingInProject CLI | `Invoke-MissingInProjectSuite.ps1 -RequireCompareReport -ViAnalyzerConfigPath configs/vi-analyzer/missing-in-project.viancfg` | Analyzer run fails with error 1003, suite performs dev-mode recovery (Close LV, re-enable token), second analyzer pass succeeds |
| 6a. MIP (2023) + LUnit lane (fast PPL enablement) | Run analyzer-gated MIP suite (2023/64), then LUnit via `.github/actions/run-unit-tests` | Scenario 5 command, followed by the run-unit-tests helper (see section below) | Analyzer report + compare manifest prove real VI compares; LUnit output confirms smoketest coverage before full PPL builds |
| 6b. Legacy MIP (2021) + LUnit lane | Same flow as 6a but allow `lv-ver=2021` / `arch=64` (set `MIP_ALLOW_LEGACY=1`) and run LUnit with matching version/bitness | Use analyzer/MIP with `-ViAnalyzerVersion 2021 -ViAnalyzerBitness 64`, then run-unit-tests helper configured for the legacy LabVIEW version | Proves the legacy LabVIEW lane can still gate dev mode and execute unit tests without the 2023 requirement |

## Execution Steps

1. Prepare staging root:

   ```powershell
   pwsh -File tools/Stage-CompareInputs.ps1 -BaseRef VI2.vi -HeadRef tmp-commit-236ffab\VI2.vi -OutputRoot c:\lab\runs\lvcompare
   ```

2. Run harness per scenario (example baseline):

   ```powershell
   pwsh -NoLogo -NoProfile -File tools/TestStand-CompareHarness.ps1 `
     -BaseVi c:\lab\runs\lvcompare\Base.vi `
     -HeadVi c:\lab\runs\lvcompare\Head.vi `
     -LabVIEWPath 'C:\Program Files\National Instruments\LabVIEW 2025\LabVIEW.exe' `
     -OutputRoot tests/results/teststand-session `
     -Warmup skip `
     -RenderReport:$false `
     -CloseLabVIEW `
     -CloseLVCompare `
     -StagingRoot c:\lab\runs\lvcompare `
     -SameNameHint
   ```

3. After each run capture:
   - `tests/results/teststand-session/session-index.json`
   - `tests/results/teststand-session/compare/lvcompare-capture.json`
   - `tests/results/_agent/reports/lvcompare/lvcompare-*.json`
4. Copy the report JSON path into the PR/issue comment so reviewers can inspect telemetry without
   full logs.

### Dev-mode detector scenario

1. Use the MissingInProject helper with analyzer + compare gating:

   ```powershell
   pwsh -File tools/icon-editor/Invoke-MissingInProjectSuite.ps1 `
     -Label mip-labtest `
     -ResultsPath tests/results `
     -RequireCompareReport `
     -ViAnalyzerConfigPath configs/vi-analyzer/missing-in-project.viancfg
   ```

2. Unset development mode (or launch LabVIEW without the token) so `MissingInProjectCLI.vi` opens
   broken. The analyzer run should surface error 1003 (Broken VI) and the helper will:
   - Close LabVIEW via the dev-mode module
   - Re-enable the dev-mode token (IconEditorDevMode helpers)
   - Retry the analyzer once
3. Verify telemetry under `tests/results/_agent/vi-analyzer/<label>/` includes the broken VI entry,
   the recovery attempt, and the successful second pass. The MissingInProject report
   (`tests/results/_agent/reports/missing-in-project/mip-labtest-*.json`) should capture:
   - `extra.viAnalyzer.brokenViCount` > 0 for attempt 1
   - `extra.viAnalyzer.retry` node with `enabled`, `attempted`, `succeeded`
   - Post-recovery compare report manifest + analyzer manifest paths

### MIP + LUnit fast path (2023 x64)

1. Run the analyzer + compare-gated MissingInProject helper (scenario 5) to ensure dev mode is
   active and LVCompare is producing real reports. The orchestration script bundles the analyzer,
   compare gate, and LUnit follow-up:

   ```powershell
   pwsh -File tools/icon-editor/Run-MipLunit-2023x64.ps1 -AutoCloseWrongLV
   ```

   > Tip: the VS Code task **IconEditor: MIP+LUnit (2023 x64)** runs the same command and keeps
   > the terminal open on failure. Exit codes: `2` missing VI Analyzer Toolkit, `3` analyzer/compare
   > failure, `4` LUnit failure, `5` g-cli missing.

2. The helper calls `.github/actions/run-unit-tests/RunUnitTests.ps1` under the hood. To rerun
   that step in isolation:

   ```powershell
   pwsh -File .github/actions/run-unit-tests/RunUnitTests.ps1 `
     -MinimumSupportedLVVersion 2023 `
     -SupportedBitness 64 `
     -ProjectPath vendor/labview-icon-editor/lv_icon_editor.lvproj `
     -ReportLabel iconeditor-lunit-labtest
   ```

3. This pairing gives a faster signal before full PPL builds:
   - Analyzer + MIP ensures dev mode is restored and the compare harness is healthy.
   - LUnit provides targeted coverage of the icon-editor project via g-cli without waiting for VIPM.
4. Capture outputs from both steps:
   - MissingInProject report (`tests/results/_agent/reports/missing-in-project/...json`) with
     analyzer retry metadata
   - LUnit telemetry/logs under `tests/results/_agent/reports/unit-tests/` plus the integration
     summary JSON referenced above

### Legacy MIP + LUnit lane (2021 x64)

1. Allow the legacy lane: set `MIP_ALLOW_LEGACY=1` and run the analyzer-gated suite with 2021 x64
   targets. The orchestrator mirrors the guardrails but tolerates the older LabVIEW binary:

   ```powershell
   pwsh -File tools/icon-editor/Run-MipLunit-2021x64.ps1 -AutoCloseWrongLV
   ```

   Ensure the VI Analyzer Toolkit for LabVIEW 2021 x64 is installed; otherwise the helper exits
   with code `2` and prints the toolkit path it attempted to locate.
2. Immediately execute LUnit against the 2021 x64 project (the helper already does this, but use
   the command below if you need to rerun it manually):

   ```powershell
   pwsh -File .github/actions/run-unit-tests/RunUnitTests.ps1 `
     -MinimumSupportedLVVersion 2021 `
     -SupportedBitness 64 `
     -ProjectPath vendor/labview-icon-editor/lv_icon_editor.lvproj `
     -ReportLabel iconeditor-lunit-legacy
   ```

3. Validate that:
   - The analyzer report shows the legacy LabVIEW path (`bitness=64`, `labviewVersion=2021`).
   - The MissingInProject report notes `MIP_ALLOW_LEGACY=1` in `extra.viAnalyzer` targets.
   - The integration summary JSON for the run references the analyzer log directory and the LUnit
     report path.

### Dev-mode stability sweep (2021 x64 POC)

Use this loop to confirm LabVIEW 2021/64 remains in development mode while exercising the analyzer
lane repeatedly.

1. Run the harness (default iterations = 3):

   ```powershell
   pwsh -File tools/icon-editor/Test-DevModeStability.ps1 `
     -LabVIEWVersion 2021 `
     -Bitness 64 `
     -Iterations 3
   ```

   This wraps `Enable-DevMode.ps1`, `Run-MipLunit-2021x64.ps1 -AutoCloseWrongLV`, and
   `Disable-DevMode.ps1` for each iteration.
   The run now enforces the reliability requirement for #595: **three consecutive iterations must
   succeed with development mode verified and no settle failures**. Expect the harness to stop early
   (exit code 1) if a LabVIEW settle guard reports an error or if verification shows the icon-editor
   token missing on any present LabVIEW target.
2. Outputs land under `tests/results/_agent/icon-editor/dev-mode-stability/`:
   - `<label>.json` contains per-iteration timings plus analyzer metadata.
   - Each iteration now records `enable.devModeVerified`, `enable.settleSeconds`, and
     `disable.settleSeconds` so you can spot noisy hosts immediately.
   - The `requirements` block specifies the `consecutiveVerifiedRequired` threshold (currently `3`),
     the observed `maxConsecutiveVerified` streak, and whether the run met the gate.
   - `latest-run.json` mirrors the last summary for quick inspection.
3. Treat `status: failed` as actionable:
   - `failure.reason` explains whether the analyzer exited non-zero, flagged dev-mode drift, or a
     wrapper script failed.
- `iterations[n].analyzer.devModeLikelyDisabled=true` indicates MissingInProjectCLI saw a broken
  dev-mode token; rerun `Enable-DevMode.ps1` before continuing other lab work.
- Each enable/disable helper also emits a `dev-mode-run@v1` telemetry document (under
  `_agent/icon-editor/dev-mode-run/`) annotated with `mode`, `settleSummary`, `settleSeconds`,
  and `verificationSummary`; the stability harness consumes these artifacts to enforce the
  reliability rule, so keep them with the summary when attaching lab evidence.

#### Latest reliability attempt (2025-11-08)

- Command: `pwsh -File tools/icon-editor/Test-DevModeStability.ps1 -LabVIEWVersion 2021 -Bitness 64 -Iterations 3`
- Result: `tests/results/_agent/icon-editor/dev-mode-stability/dev-mode-stability-20251108T193436974.json`
  reports `status=failed` / `failure.reason="Timed out waiting for LabVIEW to exit after close
  sequence."`
- Rogue traces:
  - `tests/results/_agent/icon-editor/rogue-lv/rogue-lv-enable-devmode-pre-20251108T193321241.json`
    captured the lingering `LabVIEW.exe` (PID 30476) that blocked the next enable pass.
  - `tests/results/_agent/icon-editor/rogue-lv/rogue-lv-enable-devmode-pre-20251108T192845338.json`
    covers the previous PID 40468.
- Manual `Enable-DevMode.ps1 -Versions 2021 -Bitness 64` reproduction (2025‑11‑08T19:55Z):
  - Add-token stage: `tests/results/_agent/icon-editor/dev-mode-script/enable-addtoken-2021-64-20251108T195457241.log`
    shows g-cli launched PID 41672; we terminated it via the rogue sweep.
  - Prepare stage: `tests/results/_agent/icon-editor/dev-mode-script/enable-prepare-2021-64-20251108T195516089.log`
    confirms g-cli (PID 37384) finished cleanly, but LabVIEWCLI still left a GUI session (PID 42092)
    running; `tests/results/_agent/icon-editor/dev-mode-script/close_labview-20251108T195550023.log`
    captures the close attempt and the eventual timeout.
  - Rogue notices with the same PID are available under
    `tests/results/_agent/icon-editor/rogue-lv/rogue-lv-enable-devmode-pre-20251108T195212516.json`.
- Follow-up run (`Test-DevModeStability.ps1` @ 19:58Z) produced another pair of logs:
  - `tests/results/_agent/icon-editor/dev-mode-script/enable-addtoken-2021-64-20251108T195837147.log`
    and `.../enable-prepare-2021-64-20251108T195928148.log` show both g-cli stages completing with
    exit code 0, yet LabVIEW PIDs 42804 / 21272 kept running until the sweeps killed them.
  - The final GUI PID (18424) ignored `Close_LabVIEW.ps1` and triggered another timeout; see
    rogue sweep `tests/results/_agent/icon-editor/rogue-lv/rogue-sweep-20251108T195946206.json`.
- Mitigation steps already pushed:
  - `Invoke-LabVIEWPrelaunchGuard` now loops through two settle attempts, reruns `Invoke-IconEditorRogueCheck`,
    and forcibly terminates any LabVIEW PIDs reported by the settle telemetry before retrying.
  - When g-cli still leaves orphaned LabVIEW sessions (notably after `Create_LV_INI_Token.vi`
    or `PrepareIESource.vi` runs), kill them with
    `pwsh -NoLogo -NoProfile -Command "Stop-Process -Id <pid> -Force"` or run
    `tools/Detect-RogueLV.ps1 -FailOnRogue` before rerunning the harness.
  - Each dev-mode helper call now writes its CLI transcript under
    `tests/results/_agent/icon-editor/dev-mode-script/` so we can attach logs directly to NI/CLI
    escalation threads. We also invoke `Close-LabVIEW.ps1` again inside the rogue sweep whenever a
    PID survives the first close, and we capture “before/after” rogue JSON (for example,
    `rogue-sweep-20251108T195946206.json`).
- Next diagnostic steps:
  1. Capture the LabVIEWCLI transcript for `PrepareIESource.vi` (the second g-cli invocation) to
     see why LabVIEW remains resident after CLI reports success.
  2. Experiment with longer `-SettleTimeoutSeconds` or a dedicated kill hook for the add-token
     / prepare helpers if the rogue process persists after the new guard logic.
  3. Wire `Detect-RogueLV.ps1 -FailOnRogue` after every scripted `Close-LabVIEW` invocation so we
    abort immediately when the close helper fails (instead of timing out 30 seconds later).

### LabVIEW open/close reliability requirement

- **Definition**: Every dev-mode iteration must demonstrate that LabVIEW can be opened via g-cli
  (`Create_LV_INI_Token.vi` and `PrepareIESource.vi`) and closed via `Close-LabVIEW.ps1` without
  leaving rogue LabVIEW processes. We only count an iteration as "reliable" when:
  1. The g-cli transcript logs under `tests/results/_agent/icon-editor/dev-mode-script/` show exit
     code 0 for both helper scripts and the follow-up `Invoke-LabVIEWRogueSweep` finds no live
     PIDs (`rogue.labview=[]` in the sweep JSON).
  2. The final close stage (post-`Close-IconEditorLabVIEW`) produces a "verify" rogue sweep JSON
     with no LabVIEW entries. If a PID remains (e.g. 18424, 42092), the run is considered failed
     and must be reattempted after root-causing or force-closing the offending process.
- **CLI boundary**: Development-mode helpers (enable/disable, MissingInProject, workspace reset,
  rogue sweeps) must exercise LabVIEW exclusively through **g-cli**. LabVIEWCLI is now reserved for
  LVCompare capture and VI Analyzer workloads only. If any dev-mode or reliability flow attempts to
  launch LabVIEWCLI, treat it as a regression and refactor the helper back onto the g-cli provider.
- **Artifacts to cite when escalating**:
  - `tests/results/_agent/icon-editor/dev-mode-script/enable-addtoken-2021-64-20251108T195457241.log`
    and `.../enable-prepare-2021-64-20251108T195516089.log` capture the exact CLI commands and
    timestamps for the 19:55 PT run.
  - Rogue evidence: `tests/results/_agent/icon-editor/rogue-lv/rogue-lv-enable-devmode-pre-20251108T195212516.json`,
    `.../rogue-sweep-20251108T195946206.json`, `.../rogue-sweep-20251108T200410129.json`.
  - Latest failure (PID 18424) is recorded in `rogue-lv-enable-devmode-pre-20251108T200735901.json`.
  - Close helper log: `tests/results/_agent/icon-editor/dev-mode-script/close_labview-20251108T195550023.log`.
- **Policy hook**: Run stability/reliability flows with the new `Reliability` dev-mode policy
  operation (defined in `configs/icon-editor/dev-mode-targets.json`, override via
  `ICON_EDITOR_DEV_MODE_POLICY_PATH`) so only the g-cli driven LabVIEW 2021 x64 targets are
  exercised. Pass `-DevModeOperation Reliability` to the stability harness so both
  enable/disable helpers inherit the stricter rogue-sweep enforcement. Example:

  ```powershell
  pwsh -File tools/icon-editor/Test-DevModeStability.ps1 `
    -LabVIEWVersion 2021 `
    -Bitness 64 `
    -Iterations 3 `
    -DevModeOperation Reliability `
    -ScenarioAutoCloseWrongLV `
    -EnableScriptPath tools/icon-editor/Enable-DevMode.ps1 `
    -DisableScriptPath tools/icon-editor/Disable-DevMode.ps1 `
    -ScenarioScriptPath tools/icon-editor/Run-MipLunit-2021x64.ps1 `
  ```

## Verification Checklist

1. `lvcompare-capture.json` contains `cliPath` pointing at the canonical LVCompare install.
2. Report JSON `summary` includes base/head paths and `Auto CLI` line when applicable.
3. Session index `compare.staging.enabled=true` and `compare.staging.root` matches scenario root.
4. No rogue processes left (`tools/Detect-RogueLV.ps1`) after closing the harness.
5. Scenario matrix completion: capture artifacts and expected outputs for scenarios 1 through 6b:
   - Scenario 1: `session-index.json` and `compare/lvcompare-capture.json` show no warnings.
   - Scenario 2: `session-index.json` shows `compare.autoCli=true`; report JSON contains the warmup warning.
   - Scenario 3: Missing capture warning present in the report JSON (and `compare-report.html` absent).
   - Scenario 4: Report summary records the `legacy` noise profile; capture shows canonical `cliPath`.
   - Scenario 5: Analyzer results log error 1003 on the first pass, then recovery metadata in `extra.viAnalyzer.retry`.
   - Scenario 6a: MissingInProject report + run-unit-tests telemetry both present (2023/64). The
     integration summary JSON under `_agent/reports/integration/` should show toolkit/g-cli checks
     as `ok`, analyzer + unit status `ok`, and reference the compare and LUnit artifact paths.
   - Scenario 6b: Legacy analyzer + run-unit-tests outputs present (2021/64) with
     `MIP_ALLOW_LEGACY=1`; the summary JSON should indicate the legacy schema and point at the
     analyzer directory it read.

## Contingency

- If LVCompare fails to start, capture the console transcript and rerun with
  `-Warmup spawn -DisableTimeout`.
- If reports are not written, verify `tools/report/Write-RunReport.ps1` exists on the lab runner and
  `COMPAREVI_REPORTS_ROOT` is writable.

