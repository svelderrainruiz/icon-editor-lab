# Icon Editor Dev-Mode Workflow

This workflow is the canonical way to run and debug dev-mode for the icon editor lab, both locally and in CI-like environments.

## 1. Always enter via the wrapper

Use the VS Code tasks (or the script directly) instead of ad-hoc commands:

- VS Code tasks:
  - `Local CI: Stage 25 DevMode (enable)`
  - `Local CI: Stage 25 DevMode (disable)`
  - `Local CI: Stage 25 DevMode (debug)`
- Script (what the tasks call):
  - `tests/tools/Run-DevMode-Debug.ps1`

The wrapper:

- Enforces the `$WORKSPACE_ROOT` policy (defaults to `/mnt/data/repo_local`).
- Emits a `[devmode]` banner with host info (OS, PS edition, CI vs local).
- Resolves `vendor/labview-icon-editor` (or `vendor/icon-editor` as a fallback).
- Ensures dev-mode helper scripts are mirrored into `.github/actions/*`.

## 2. On failure, inspect telemetry instead of re-running blindly

When dev-mode fails, the wrapper prints:

- A one-line failure summary.
- The path to `tests/results/_agent/icon-editor/dev-mode-run/latest-run.json`.
- A tip pointing at the telemetry helper and VS Code task.

Always follow up with one of:

- VS Code task:
  - `Local CI: Show last DevMode run`
- Script:
  - `pwsh -NoLogo -NoProfile -File tests/tools/Show-LastDevModeRun.ps1`

This helper summarizes the latest run:

- `mode`, `operation`, `status`.
- `requestedVersions`, `requestedBitness`.
- `errorSummary` (e.g., g-cli timeouts, rogue LabVIEW, path issues).
- `statePath` and `verificationSummary` if present.
- The full telemetry JSON path.

Optionally, pass:

- `-RawJson` to dump the full payload.
- `-Open` to open `latest-run.json` in VS Code (if `code` is on `PATH`) or the default viewer.

## 3. Deepen debugging only as needed

Use this escalation path:

1. Wrapper task → failure summary + telemetry hint.
2. `Show-LastDevModeRun.ps1` → high-signal summary.
3. `Show-LastDevModeRun.ps1 -RawJson` or open `latest-run.json` → full context.
4. Only then:
   - `tools/icon-editor/Enable-DevMode.ps1` / `Disable-DevMode.ps1` with targeted parameters.
   - Vendor scripts under `vendor/labview-icon-editor/Tooling/*` if the failure is within LabVIEW/g-cli itself.

## 4. Tests and docs that use this workflow

Dev-mode tests and docs are aligned with this workflow:

- Tests:
  - `src/tests/LvAddonDevMode.Tests.ps1`
  - `src/tests/IconEditorDevMode.Telemetry.Tests.ps1`
- Docs:
  - `src/tests/_docs/Enable-Disable-DevMode.Tests.ps1.md`

When working on dev-mode behavior, start from these tests and docs, and use the wrapper + telemetry helper as your primary tools rather than calling vendor scripts directly.

## 5. LvAddonRoot logging & review gate

- Every dev-mode entry point logs the resolved path before touching `Localhost.LibraryPaths`:
  - `[devscript] LvAddonRoot="<path>" Source=<parameter|env|resolved> [Mode=Strict] Origin=<url> Host=<host> LVAddon=<True|False> Contributor=<your-gh-login>` (the `Mode` token only appears for strict policy enforcement)
  - The same data is persisted in telemetry (`lvAddonRootPath`, `...Source`, `...Origin`, `...Host`, `...IsLVAddonLab`, `...Contributor`).
- The `Origin` field is normalized to the authenticated GitHub user (read via `gh auth status`, your local `icon-editor-lab` fork, or the `ICONEDITORLAB_GITHUB_LOGIN` override), so reviewers always see the contributor’s fork URL. If no fork can be detected, the tooling falls back to `ni/labview-icon-editor`.
- After running a dev-mode task locally, run the gated review task to acknowledge the path:
  - VS Code composite tasks:
    - `Local CI: Stage 25 DevMode (enable + review)`
    - `Local CI: Stage 25 DevMode (disable + review)`
  - These run the normal enable/disable scripts, then automatically invoke `DevMode: Review last run (human gate)` which surfaces the path (via `tests/tools/Verify-DevModeLog.ps1`) and pauses for your confirmation.
- CI jobs parse the same telemetry; if the path log is missing, they fail early so reviewers always see which LV add-on lab (LVADDONLAB) was targeted.
