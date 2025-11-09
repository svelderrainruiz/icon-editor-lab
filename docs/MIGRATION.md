# Icon Editor Lab Migration Plan

## Phase 1 – carve-out (current)

- Copy existing lab docs (`ICON_EDITOR_PACKAGE.md`, `LVCOMPARE_LAB_PLAN.md`,
  `LABVIEW_GATING.md`, `TROUBLESHOOTING.md`) and configs
  (`configs/icon-editor/**`, `configs/vi-analyzer/**`) from
  `compare-vi-cli-action`.
- Mirror all `tools/` modules (dev-mode helpers, VendorTools, LabVIEW CLI
  shims, rogue detectors, etc.) plus the `vendor/icon-editor` fixture so tests
  can continue to run in isolation.
- Bring over the icon-editor Pester suites and `Invoke-PesterTests.ps1`.
- Add minimal CI (GitHub Actions) that runs the most critical suites:
  `Enable-Disable-DevMode`, `IconEditorDevMode.Telemetry`, and
  `IconEditorDevMode.Stability`.

## Phase 2 – establish clean boundaries

- Track remaining hard-coded references to `compare-vi-cli-action` (see
  `docs/DEPENDENCIES.md`) and remove or rewrite them so this repo stands alone.
- Keep `tools/Export-LabTooling.ps1` as the canonical bundling mechanism.
  Downstream consumers should either download the ZIP (preferred) or add this
  repo as a submodule. Usage details live in `docs/CONSUMPTION.md`.
- Audit shared helpers (schemas, dashboards, GitHub automation scripts) and
  decide which belong here vs. the composite repo. Drop anything that isn’t
  required for the lab scenarios.
- Extend CI with additional suites (VI Analyzer, VIPM packaging) as we trim
  cross-repo dependencies, ensuring the exported artifact remains tested.

## Phase 3 – flip consumers

- Update `compare-vi-cli-action` to pull the lab tooling from this repo instead
  of keeping its own copy. Remove the duplicated files there and replace them
  with documentation pointing at `icon-editor-lab`.
- Archive / mark read-only the lab-specific folders in
  `compare-vi-cli-action` once CI proves the new setup is stable.
- Keep `icon-editor-lab` as the canonical home for dev-mode policies, rogue
  detection scripts, VI Analyzer configs, and lab docs going forward.
