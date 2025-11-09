<!-- markdownlint-disable-next-line MD041 -->
# Troubleshooting Guide

Common issues when running the LVCompare composite action.

## Installation / path issues

### LVCompare not found

Symptoms: "LVCompare.exe not found at canonical path".

Fix:

```powershell
Test-Path 'C:\Program Files\National Instruments\Shared\LabVIEW Compare\LVCompare.exe'
```

Only the canonical path is supported; ensure LabVIEW 2025 Q3 (compare feature) is installed.

### Custom path rejected

Even when `lvComparePath`/`LVCOMPARE_PATH` is provided, it must resolve to the canonical
location. Update the runner install if the CLI lives elsewhere.

### Custom install layout

- Copy `configs/labview-paths.sample.json` to `configs/labview-paths.json` to
  list non-default `LVCompare.exe` / `LabVIEW.exe` locations. The helpers will
  read those paths before scanning the canonical Program Files directories.
- Run scripts with `-Verbose` (or `pwsh -v 5`) to see every candidate path the
  resolver evaluates when debugging missing installs.

## Exit codes & behaviour

| Exit code | Meaning | Notes |
| --------- | ------- | ----- |
| 0 | Identical | No diffs detected |
| 1 | Differences | Review outputs, HTML report |
| 2 | Invocation error | Inspect logs, rerun locally |

## Missing or stale LVCompare HTML

If `-RequireCompareReport` is enabled and `compare-report.html` is missing, the MissingInProject
suite fails. Inspect the harness logs under the run directory and the compare image analyzer output
(`compare-image-summary.json` / `compare-image-manifest.json`) for details.

- In local/dev flows, you can enable a safe fallback compare to unblock the gate without running a full suite:
  - Set `MIP_COMPARE_BASE` and `MIP_COMPARE_HEAD` (absolute VI paths).
  - Optionally set `MIP_COMPARE_RUNNER` to a runner script (defaults to `tools/Run-HeadlessCompare.ps1`).
  - Optionally set `MIP_COMPARE_ANALYZER` to a custom analyzer script for image manifest extraction.
  - The suite re-runs the analyzer post-fallback to emit a manifest and then applies the image heuristics.

If the fallback still doesn't produce the HTML or the analyzer fails, verify LabVIEW 2025 x64
LVCompare is installed and that rogue LabVIEW processes are not interfering.
Run `tools/Detect-RogueLV.ps1 -FailOnRogue` and close unexpected instances or set
`MIP_AUTOCLOSE_WRONG_LV=1`.

## Analyzer reports "Broken VI" or error 1125 (saved in newer LV)

If the analyzer reports broken VIs, the MissingInProject helper performs one dev-mode recovery
attempt (close LV, enable dev mode, retry analyzer). If the second pass remains broken, the run
fails and points to the analyzer report.

For error 1125 (VI saved in newer version), the helper fails immediately. Ensure the targeted VI is
saved for the analyzer's LabVIEW version (default 2023 x64) or update the analyzer targets.

### Quick guardrail checklist

- Composite `.github/actions/missing-in-project` expects `lv-ver=2023`, `arch=64` (override with
  `MIP_ALLOW_LEGACY=1`).
- Suite preflight detects and optionally closes non-expected LabVIEW instances:
  `MIP_ROGUE_PREFLIGHT=1`, `MIP_AUTOCLOSE_WRONG_LV=1`, `MIP_EXPECTED_LV_VER=2023`,
  `MIP_EXPECTED_ARCH=64`.

Set `fail-on-diff: false` to treat code 1 as notice-only.

## Performance checklist

- Use noise filters (`-noattr -nofp -nofppos -nobd -nobdcosm`).
- Shorten paths with `working-directory`.
- For UNC/long paths, map a drive or enable long-path support.

## Watcher / busy-loop signals

- `[hang-watch]` / `[hang-suspect]` → idle for extended periods.
- `[busy-watch]` / `[busy-suspect]` → log growing without progress markers.
- Use `node tools/npm/run-script.mjs dev:watcher:status` to inspect heartbeat freshness; run
  `node tools/npm/run-script.mjs dev:watcher:trim` if `needsTrim=true`.

## Loop mode hiccups

- Check `tests/results/loop/**` for JSON logs and timing stats.
- Enable leak detection (`tools/Detect-RogueLV.ps1 -FailOnRogue`).
- Close LVCompare after loop runs (`tools/Close-LVCompare.ps1`).
- Post-run cleanup retries LabVIEW shutdown automatically (up to three attempts).
  If it still fails, inspect `tests/results/_agent/post/post-run-cleanup.log`
  where the script now reports remaining PID lists before throwing and then falls
  back to `tools/Force-CloseLabVIEW.ps1` to terminate LabVIEW/LVCompare forcibly.

## Test environment tips

- Run `./Invoke-PesterTests.ps1 -IntegrationMode include` to repro CI suites.
- Use `tools/Dev-Dashboard.ps1` for a quick telemetry snapshot (locks, queue waits).
- Hand-offs: `tools/Print-AgentHandoff.ps1 -AutoTrim` surfaces watcher state and trims logs.
- Spot-check LVCompare/LabVIEWCLI behaviour locally with
  `tools/Verify-LocalDiffSession.ps1`; VS Code tasks **Local: Verify diff session (stub)**
  and **Local: Verify diff session (real)** wire in the common parameters.

## Run report hand-offs

- All helpers that emit run summaries (host prep, missing-in-project, LVCompare harness,
  unit-test runner, etc.) drop JSON files under `tests/results/_agent/reports/<kind>/`.
- Each report captures the command line, transcript/telemetry paths, warnings, and extra
  metadata so you can share a single path (for example,
  `tests/results/_agent/reports/lvcompare/lvcompare-20251107T101500.json`) instead of
  pasting entire transcripts into an issue.
- When troubleshooting with another engineer, provide that JSON path and they can recover
  the referenced transcripts/artifacts directly from the repo checkout or attached artifacts.

## Git difftool overlap (duplicate CLI invocations)

Symptoms: LabVIEWCLI.exe appears to launch twice during a manual diff, or CLI capture runs
unexpectedly when using a Git difftool/IDE diff.

Why it happens:

- Git difftool/mergetool may be configured to invoke LabVIEWCLI, while the compare helper also uses
  the CLI (CreateComparisonReport) to generate HTML artifacts. Both can fire for the same intent.

Mitigations:

- Suppress CLI capture during Git difftool sessions:

```powershell
$env:COMPAREVI_SUPPRESS_CLI_IN_GIT = '1'   # skip CLI when a Git context is detected
$env:COMPAREVI_WARN_CLI_IN_GIT     = '1'   # optional: emit a warning when in Git context
```

- Short‑TTL duplicate suppression for repeated compare of the same pair:

```powershell
$env:COMPAREVI_CLI_SENTINEL_TTL = '60'     # seconds; suppress duplicate CLI for (vi1,vi2[,reportPath]) within TTL
```

- Hard opt‑out (no CLI capture at all in the current process):

```powershell
$env:COMPAREVI_NO_CLI_CAPTURE = '1'
```

Notes:

- These toggles are process-scoped. Set them in the same shell/terminal that runs the compare.
- When suppression is active, the capture JSON records `environment.cli.skipped=true` with a
  `skipReason` (e.g., `git-context`).

## Further reading

- [`README.md`](../README.md)
- [`docs/USAGE_GUIDE.md`](./USAGE_GUIDE.md)
- [`docs/COMPARE_LOOP_MODULE.md`](./COMPARE_LOOP_MODULE.md)
- [`docs/DEV_DASHBOARD_PLAN.md`](./DEV_DASHBOARD_PLAN.md)

