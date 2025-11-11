# Consuming Icon Editor Lab Tooling

`compare-vi-cli-action` (and any other automation) should treat this repo as the
canonical source for Icon Editor dev-mode tooling. Downstream consumers have two
options:

## 1. Versioned artifact (recommended)

Use `tools/Export-LabTooling.ps1` to produce a ZIP containing the directories
needed by the composite action:

```powershell
pwsh -File tools/Export-LabTooling.ps1 `
  -Destination artifacts/icon-editor-lab-tooling.zip `
  -Force
```

Include the resulting archive in a GitHub release (or publish it to your
artifact feed). Consumers download and extract it under their workspace,
ensuring the following relative paths exist:

- `tools/**` – PowerShell modules and scripts
- `configs/**` – dev-mode/VI Analyzer policy files
- `vendor/icon-editor/**` – LabVIEW project + fixture assets
- `docs/LVCOMPARE_LAB_PLAN.md` (and related operational docs)

Advantages:

- No need to add submodules or clone large histories in the action repo.
- Allows semantic versioning / release notes per lab drop.
- Easy to cache in CI.

## 2. Git submodule or subtree

Reference this repository directly inside `compare-vi-cli-action`, e.g.:

```bash
git submodule add https://github.com/svelderrainruiz/icon-editor-lab vendor/icon-editor-lab
```

Ensure build scripts add the submodule path to `$env:PSModulePath` (or use
relative paths when invoking lab helpers). This keeps the lab history visible
but adds extra clone time and requires submodule syncs.

## Compatibility contract

- PowerShell entry points (`tools/icon-editor/*.ps1`, `Invoke-PesterTests.ps1`,
  `tools/Export-LabTooling.ps1`) constitute the supported API surface.
- Telemetry written under `tests/results/_agent/icon-editor/**` follows the
  schemas defined in `docs/LVCOMPARE_LAB_PLAN.md` and should not change without
  a major version bump.
- Consumers should not rely on internal test helpers or private scripts under
  `tests/_helpers`—only the exported modules in `tools/` are stable.

Track the currently deployed artifact/submodule commit in the downstream repo so
we can reason about upgrades and breaking changes.
