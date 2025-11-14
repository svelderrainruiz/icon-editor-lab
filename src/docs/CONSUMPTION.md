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
- `vendor/labview-icon-editor/**` – LabVIEW project + fixture assets
- `docs/LVCOMPARE_LAB_PLAN.md` (and related operational docs)

Advantages:

- No need to add submodules or clone large histories in the action repo.
- Allows semantic versioning / release notes per lab drop.
- Easy to cache in CI.

## 2. Git submodule or subtree

Reference this repository directly inside `compare-vi-cli-action`, e.g.:

```bash
git submodule add https://github.com/svelderrainruiz/icon-editor-lab vendor/labview-icon-editor-lab
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

## 3. Downstream local-CI handshake (self-hosted)

Fork owners who run their own Windows pipeline should reproduce the Ubuntu→Windows handshake that upstream enforces:

1. Run `local-ci/ubuntu/invoke-local-ci.sh` in CI to generate `out/local-ci-ubuntu/<stamp>` and `latest.json`.
2. Upload that directory as an artifact (`ubuntu-local-ci-<stamp>` is the convention used in `.github/workflows/local-ci-handshake.yml`).
3. Before the Windows job executes, download the artifact, copy it back to `out/local-ci-ubuntu/<stamp>` inside the workspace, and set `LOCALCI_IMPORT_UBUNTU_RUN` to the restored `ubuntu-run.json`.
4. Invoke `local-ci/windows/Invoke-LocalCI.ps1` (all stages or targeted ones) so Stage 10 automatically imports the Ubuntu payload before VI compare logic runs.

You can scaffold the workflow into any fork with:

```powershell
pwsh -File local-ci/scripts/New-HandshakeWorkflow.ps1 `
  -TargetRepoRoot C:\src\my-fork `
  -WindowsRunsOn '[self-hosted, windows]'
```

That script copies `.github/workflows/local-ci-handshake.yml` into the target repo and, when `-WindowsRunsOn` is supplied, rewrites the Windows job to use your self-hosted label.

