# Icon Editor VI Package Build Notes
<!-- markdownlint-disable MD013 -->

This repository no longer tracks a prebuilt Icon Editor VIP. Every
package is produced on demand by the CI pipeline (and by the local
helpers) from the current sources.

## Building locally

The composite workflow and the helper scripts expect LabVIEW 2021
(32-bit and 64-bit) for the PPL builds and LabVIEW 2023 (32-bit and
64-bit) for the VIPM packaging step. To build the package on a workstation:
the VIPM CLI packaging step. To build the package on a workstation:

```powershell
# Install VIPC dependencies (preferred helper)
pwsh -File tools/icon-editor/Invoke-VipmDependencies.ps1 `
  -MinimumSupportedLVVersion 2021 `
  -VIP_LVVersion 2023 `
  -SupportedBitness 32,64

# Display installed packages only (no install)
pwsh -File tools/icon-editor/Invoke-VipmDependencies.ps1 `
  -MinimumSupportedLVVersion 2026 `
  -VIP_LVVersion 2026 `
  -SupportedBitness 64 `
  -DisplayOnly


# Enable the required LabVIEW development modes for packaging
pwsh -File tools/icon-editor/Enable-DevMode.ps1 `
  -RepoRoot . `
  -IconEditorRoot vendor/icon-editor `
  -Operation BuildPackage

# Run the non-LV dependency install and package build helpers as needed.
pwsh -File tools/Run-NonLVChecksInDocker.ps1
pwsh -File tools/icon-editor/Invoke-VipmCliBuild.ps1

# After the build completes, disable development mode.
pwsh -File tools/icon-editor/Disable-DevMode.ps1 `
  -RepoRoot . `
  -IconEditorRoot vendor/icon-editor `
  -Operation BuildPackage

# (Optional) Force a clean LabVIEW workspace reset.
pwsh -File tools/icon-editor/Reset-IconEditorWorkspace.ps1 `
  -RepoRoot . `
  -IconEditorRoot vendor/icon-editor `
  -Versions 2023 `
  -Bitness 32,64
```

The helpers will drop the packaged VIP under `builds/VI Package/`.
Upload the resulting VIP to artifact storage (or attach it to a release)
instead of committing it to the repository.

> **Note**  
> `Disable-DevMode.ps1` already calls the reset helper so CI and scripted builds return LabVIEW to a clean state automatically. The explicit `Reset-IconEditorWorkspace.ps1` invocation above is handy when you abort a run midway, experiment with g-cli manually, or need to clean only a subset of versions/bitness before the next build.

### G-CLI dependency install prerequisites

- Install G CLI 3.x and ensure `C:\Program Files\G-CLI\bin\g-cli.exe` (override via `GCLI_EXE_PATH` or `configs/labview-paths.local.json` only when necessary).
- Verify the binary with `g-cli --version` before invoking the helper.
- `Invoke-VipmDependencies.ps1` always shells through g-cli (`vipm-gcli`) for installs so each run loops over LabVIEW 2021/2023 × 32-bit and 64-bit when you supply both versions and `-SupportedBitness 32,64`.
- Display-only runs switch to the classic VIPM CLI automatically to enumerate installed packages; no provider flag is required.
- Each dependency install writes telemetry under `tests/results/_agent/icon-editor/vipm-install/`. Review those JSON logs to see the exact command, arguments, and exit code for a given run.
- The legacy `.github/actions/apply-vipc/ApplyVIPC.ps1` wrapper now shells directly into `Invoke-VipmDependencies.ps1` and exists only to support the composite action. All new scripts should call the helper directly.

### VI Analyzer preflight (2023 x64 guardrails)

`Invoke-MissingInProjectSuite.ps1` now runs the VI Analyzer before g-cli. You can invoke the analyzer wrapper directly:

```powershell
pwsh -File tools/icon-editor/Invoke-VIAnalyzer.ps1 `
  -ConfigPath configs/IconEditor.viancfg `
  -OutputRoot tests/results/_agent/vi-analyzer `
  -LabVIEWVersion 2023 `
  -Bitness 64 `
  -ReportSaveType HTML `
  -CaptureResultsFile
```

Set `MIP_VIANALYZER_CONFIG` (or pass `-ViAnalyzerConfigPath`) so the suite uses the analyzer gate. Analyzer artifacts land under `tests/results/_agent/vi-analyzer/<label>/` and the MissingInProject reports now include `extra.viAnalyzer` metadata pointing at the analyzer run.

Guardrails and env variables:

- The MissingInProject composite action enforces LabVIEW 2023 (64-bit) inputs; set `MIP_ALLOW_LEGACY=1` to bypass.
- The suite helper runs a rogue-LabVIEW preflight and either closes or fails on unexpected instances:
  - `MIP_ROGUE_PREFLIGHT=1` (default)
  - `MIP_AUTOCLOSE_WRONG_LV=1` to auto-close non‑expected LabVIEW
  - `MIP_EXPECTED_LV_VER=2023`, `MIP_EXPECTED_ARCH=64`
- Enforce real LVCompare output:
  - `MIP_REQUIRE_COMPARE_REPORT=1`
  - Fallback compare (local/dev only): `MIP_COMPARE_BASE`, `MIP_COMPARE_HEAD`, optional `MIP_COMPARE_RUNNER`, `MIP_COMPARE_ANALYZER`
- Analyzer and retry:
  - `MIP_VIANALYZER_CONFIG`, `MIP_VIANALYZER_LABEL`, `MIP_VIANALYZER_TIMEOUT_SECONDS`
  - `MIP_DEV_MODE_RETRY_ON_BROKEN_VI=1`, `MIP_DEV_MODE_RETRY_DELAY_SECONDS=5`, `MIP_DEV_MODE_VERSIONS`, `MIP_DEV_MODE_BITNESS`, `MIP_DEV_MODE_RECOVERY_HELPER`
- g-cli retries:
  - `MIP_GCLI_RETRY_COUNT=1`, `MIP_GCLI_RETRY_DELAY_SECONDS=5`, `MIP_GCLI_CONNECT_TIMEOUT_MS`

Retry/timeout knobs:

- `MIP_GCLI_RETRY_COUNT` (default 1) and `MIP_GCLI_RETRY_DELAY_SECONDS` control how many times the MissingInProject helper retries g-cli before failing.
- `MIP_GCLI_CONNECT_TIMEOUT_MS` overrides the g-cli `--connect-timeout` (default 180000 ms).
- `MIP_VIANALYZER_CONFIG` can be set in CI so every suite run automatically enables the analyzer gate without passing `-ViAnalyzerConfigPath` manually.
- `MIP_DEV_MODE_RETRY_ON_BROKEN_VI` (default `1`) enables the new “broken VI” recovery loop: when the analyzer reports a broken VI the helper closes LabVIEW, re-enables dev mode for the policy targets, waits `MIP_DEV_MODE_RETRY_DELAY_SECONDS` (default `5`), and reruns the analyzer once. Use `MIP_DEV_MODE_VERSIONS` / `MIP_DEV_MODE_BITNESS` to override the policy targets or `MIP_DEV_MODE_RECOVERY_HELPER` when you need to stub the recovery logic in tests.

See `docs/vi-analyzer/README.md` for more VI Analyzer CLI tips and error-code references.

### VIPM CLI prerequisites (packaging lane)

- Install the VIPM CLI and ensure it is available on `PATH` (or set `VIPM_PATH`/`VIPM_EXE_PATH`).
- Verify the tooling before running dependency installs or package builds:

  ```powershell
  vipm --version
  vipm build --help
  ```

- Confirm LabVIEW 2026 (64-bit) is installed/registered via
  `Find-LabVIEWVersionExePath`. `ApplyVIPC.ps1` now fails fast when the
  CLI or the LabVIEW beta are missing.

## CI packaging flow (overview)

- `apply-deps`: installs the required VIPCs for each LabVIEW target via
  the VIPM CLI (default). The step runs the readiness checks above and
  uploads the telemetry logs.
- `enable-dev-mode`: enables the icon-editor development mode for the
  relevant LabVIEW versions/bitness.
- `build-ppl`: builds the packed libraries for 32-bit and 64-bit LabVIEW
  2023.
- `build-vi-package`: runs the VIPM CLI against LabVIEW 2026 to produce
  the distributable VIP. The built artifacts are uploaded via
  `actions/upload-artifact`.
- `disable-dev-mode`: returns each LabVIEW installation to its original
  state, even if earlier steps failed.

Inspect the workflow artifacts (`vi-package` and `vipm-build-logs`) to
review the generated VIPs and the associated metadata.

### Dev-mode telemetry helpers

- Script authors should call `Initialize-IconEditorDevModeTelemetry`,
  `Invoke-IconEditorTelemetryStage`, and
  `Complete-IconEditorDevModeTelemetry` (all exported from
  `tools/icon-editor/IconEditorDevMode.psm1`) whenever they enable or
  disable dev mode. The helpers manage `tests/results/_agent/icon-editor/dev-mode-run`,
  capture settle events automatically, and persist verification
  summaries so downstream tooling (stability harness, dashboards, lab
  plans) can reason about each iteration with consistent JSON. Avoid
  writing ad-hoc telemetry—if a new stage needs instrumentation, wrap it
  in `Invoke-IconEditorTelemetryStage` and let the shared helpers do the
  bookkeeping.

## Validation tips

- Use `tools/icon-editor/Invoke-ValidateLocal.ps1` when you need a
  full-package smoke test locally. The script now operates on the
  generated VIP rather than a committed fixture.
- The `Prepare-FixtureViDiffs.ps1` and
  `Describe-IconEditorFixture.ps1` helpers accept an explicit `-FixturePath`
  so you can point them at any VIP generated by the build pipeline or a
  downloaded artifact.

## LabVIEW host prep for MissingInProject

- Use `pwsh -File tools/icon-editor/Prepare-LabVIEWHost.ps1` to stage the
  latest fixture VIP, enable icon-editor dev mode for the requested
  LabVIEW versions/bitness, close LabVIEW so the dev-mode token loads,
  and reset the workspace before running the MissingInProject suite.
  Example:

  ```powershell
  pwsh -File tools/icon-editor/Prepare-LabVIEWHost.ps1 `
    -FixturePath C:\builds\ni_icon_editor-1.4.1.948.vip `
    -Versions 2021 `
    -Bitness 32,64 `
    -StageName host-prep
  ```

- Each run writes a telemetry record under
  `tests/results/_agent/icon-editor/host-prep/` describing the inputs,
  executed steps, and any forced LabVIEW shutdowns. Attach that JSON to
  issue updates when diagnosing host-prep problems. The telemetry (and
  console summary) now include a `devModeTelemetry` block with links to
  the corresponding `dev-mode-run@v1` artifacts (`enable` for the main
  host-prep run and `guardDisable` when the safety check had to disable
  an unexpected dev-mode instance), so lab operators can jump directly to
  the settle/verification data that backs the host prep.
- The helper waits for LabVIEW to close after every stage (or forces a
  shutdown via `tools/Close-LabVIEW.ps1` → `Stop-Process` if needed)
  before moving on, so rerunning it is safe and idempotent.
- The helper runs rogue-LabVIEW detection before and after the prep
  steps, sets the `LV_*` safety toggles, and writes its summary to the
  console. Pass `-DryRun` to exercise the staging pipeline without
  enabling dev mode or closing LabVIEW.
- VS Code exposes the same workflow via the
  **IconEditor: Prepare LabVIEW Host** task (Ctrl+Shift+B). Supply the
  fixture path, versions, bitness, and stage name when prompted and the
  task will queue the helper with those values.

### Dev-mode detection runs

- The MissingInProject helper plus VI Analyzer gate now doubles as a development-mode detector.
  When `Invoke-MissingInProjectSuite.ps1` runs with `-RequireCompareReport` and a VI Analyzer config,
  it surfaces error 1003 when `MissingInProjectCLI.vi` opens broken (dev mode unset) and automatically
  runs the recovery helper (close LabVIEW, re-enable dev mode, rerun analyzer). The telemetry records
  the broken VI list plus the retry metadata under `extra.viAnalyzer.retry`.
- Use the lab plan `docs/LVCOMPARE_LAB_PLAN.md` scenario 5 to validate this flow on hardware: unset
  dev mode intentionally, run the suite, confirm the first analyzer pass fails with error 1003, and
  confirm the retry succeeds with a real compare report.
- Install the VI Analyzer Toolkit for each LabVIEW version you plan to use (2023/64 for scenario 6a
  and 2021/64 for scenario 6b). LabVIEWCLI returns error `-350053` when the toolkit is missing or
  not activated.
- For a fast pre-PPL confidence lane, chain the analyzer-gated MIP run with the LabVIEW unit tests
  helper (`pwsh -File .github/actions/run-unit-tests/RunUnitTests.ps1 -MinimumSupportedLVVersion 2023 -SupportedBitness 64 -ProjectPath vendor/icon-editor/lv_icon_editor.lvproj`). This gives a quick
  signal before kicking off the heavier VIPM pipeline.

## Housekeeping

- The repository deliberately keeps `tests/fixtures/icon-editor/`
  empty. Do not add built VIPs or manifests back into source control;
  rely on workflow artifacts instead.
- Documentation that previously referenced the committed fixture has
  been updated to this page. If you find outdated references to
  `tests/fixtures/icon-editor`, replace them with guidance that points
  to the on-demand build flow.

