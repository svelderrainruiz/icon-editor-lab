# Test-DevModeStability.ps1

**Path:** `tools/icon-editor/Test-DevModeStability.ps1`

## Synopsis
Run repeated enable/disable/dev-mode scenarios (default: Run-MipLunit-2021x64) to prove LabVIEW development mode remains healthy for the requested version/bitness.

## Description
- Intended to satisfy the reliability gate in IELA-SRS-F-001: requires three consecutive verified iterations by default.
- Resolves repo + icon-editor roots, then locates helper scripts (enable/disable wrappers plus a scenario such as `Run-MipLunit-2021x64.ps1`).
- For each iteration the harness:
  1. Calls the scenario script (typically MissingInProject + analyzer) with auto-close, dry-run, and additional argument options.
  2. Verifies dev-mode telemetry (`dev-mode-run@v1`) and analyzer outputs, updating `tests/results/_agent/icon-editor/dev-mode-stability/<label>.json`.
  3. Tracks consecutive passes, failing early if verification breaks or rogue LabVIEW processes remain.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `LabVIEWVersion` | int | `2021` | Target LabVIEW version for the scenario script. |
| `Bitness` | 32/64 | `64` | LabVIEW bitness. |
| `Iterations` | int (1–20) | `3` | Total iterations to attempt; harness requires all iterations to pass consecutively. |
| `DevModeOperation` | string | `Reliability` | Annotated in dev-mode telemetry. |
| `RepoRoot` | string | Resolved automatically | Allows running from staged bundles. |
| `ResultsRoot` | string | `tests/results` | Base directory for `_agent/icon-editor/dev-mode-stability`. |
| `EnableScriptPath` / `DisableScriptPath` | string | Defaults under `tools/icon-editor` | Override the wrapper scripts if needed. |
| `ScenarioScriptPath` | string | `tools/icon-editor/Run-MipLunit-2021x64.ps1` | Script executed between enable/disable steps (must accept the documented scenario parameters). |
| `ScenarioProjectPath`, `ScenarioAnalyzerConfigPath`, `ScenarioResultsPath` | string | — | Provide when the scenario script needs explicit project/config/results overrides. |
| `ScenarioAutoCloseWrongLV` | bool | `$true` | Passes through to the scenario script to close non-target LabVIEW instances automatically. |
| `ScenarioDryRun` | bool | `$false` | If `$true`, scenario script should log intent without executing LabVIEW. |
| `ScenarioAdditionalArguments` | string[] | — | Extra arguments forwarded to the scenario script. |

## Exit Codes
- `0` — Required number of consecutive verified iterations completed.
- `1` — Harness stopped early (missing analyzer artifacts, dev mode failed verification, rogue processes, etc.).

## Related
- `tools/icon-editor/Enable-DevMode.ps1`
- `tools/icon-editor/Disable-DevMode.ps1`
- `tools/icon-editor/Run-MipLunit-2021x64.ps1`
- `docs/LABVIEW_GATING.md`
