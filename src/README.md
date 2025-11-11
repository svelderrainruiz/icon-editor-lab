# Icon Editor Lab

This repository hosts the LabVIEW Icon Editor lab automation and reliability
tooling that previously lived under `compare-vi-cli-action`. It includes:

- Dev-mode enable/disable helpers, rogue detection, and stability sweeps
  (`tools/icon-editor`).
- Test fixtures, VI Analyzer configs, and policy documents under `configs/`
  and `docs/`.
- The Pester suites that gate dev-mode, VI Analyzer, VIPM, and compare flows
  locally and in CI.

Consumption patterns (artifact vs. submodule) are described in
`docs/CONSUMPTION.md`. Use `tools/Export-LabTooling.ps1` to produce a portable
bundle for downstream repos such as `compare-vi-cli-action`. To generate a VI
Comparison HTML report locally, see `docs/VI_COMPARE_SMOKE.md` and run
`tools/Run-VICompareSample.ps1`.

## Getting Started

```powershell
git clone https://github.com/svelderrainruiz/icon-editor-lab.git
cd icon-editor-lab
pwsh -File Invoke-PesterTests.ps1
```

CI wiring is still being migrated from `compare-vi-cli-action`; use the
existing lab plan (`docs/LVCOMPARE_LAB_PLAN.md`) as the source of truth for
required scenarios until the move is complete.

## Documentation Package

- `docs/README.md` – quick map, scenario cheat sheet, reliability criteria, smoke reference.
- `AGENTS.md` – expectations for automation agents (first actions, bundle workflow, hand-off notes).
- `docs/MIGRATION.md` / `docs/DEPENDENCIES.md` – migration plan plus remaining cross-repo references.
- `docs/CONSUMPTION.md` – bundle export/import instructions for downstream repos.
- `docs/LVCOMPARE_LAB_PLAN.md` – detailed scenario matrix (1–6b) and artifact requirements.
- `docs/VI_COMPARE_SMOKE.md` – how to produce a real LVCompare HTML report.
- `docs/ICON_EDITOR_LAB_MIGRATION.md` – success criteria for the carve-out.
