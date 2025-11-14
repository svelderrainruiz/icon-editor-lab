# IconEditorDevMode.psm1

**Path:** `tools/icon-editor/IconEditorDevMode.psm1`

## Synopsis
Utility module for managing icon-editor dev-mode state: resolve repo paths, write/read dev-mode state JSON, and run rogue-process checks.

## Description
- Resolves the vendor icon-editor repo root (`vendor/labview-icon-editor`) and keeps the dev-mode state file at `tests/results/_agent/icon-editor/dev-mode-state.json`.
- Provides helpers:
  - `Resolve-IconEditorRepoRoot` / `Resolve-IconEditorRoot` – find repo/vendor paths.
  - `Get-IconEditorDevModeState` / `Set-IconEditorDevModeState` – read/write `icon-editor/dev-mode-state@v1`.
  - `Invoke-IconEditorRogueCheck` – call `tools/Detect-RogueLV.ps1` with optional auto-close/fail-on-rogue behavior.
- Used by scripts like `Enable-DevMode`, `Disable-DevMode`, and `Test-DevModeStability` to keep state consistent across runs.

## Related
- `tools/icon-editor/Enable-DevMode.ps1`
- `tools/Detect-RogueLV.ps1`

