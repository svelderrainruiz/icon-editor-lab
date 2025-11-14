# Developer Quickstart (Local CI + LabVIEW)

## Prerequisites (Windows)
- PowerShell 7.4+
- LabVIEW (2021/2023), matching bitness for your workflows
- VIPM installed and running (required for dependency apply)
- Optional: G CLI if your environment relies on it
- Optional helper: `local-ci\windows\run-local-ci.cmd` lets you kick off the Windows runner directly from Command Prompt (`run-local-ci.cmd -SkipStages 40`).

## Prerequisites (WSL/Ubuntu)
- Docker Desktop/Engine (for container checks)
- PowerShell 7 (pwsh) — see notes below and `docs/local-ci-runner.md`

## Node & npm setup (All Platforms)
- Install Node.js 20 LTS or newer. Windows users can grab the installer from [nodejs.org](https://nodejs.org/) (the setup also adds `npm` and `npx` to PATH); WSL/Ubuntu users can use the NodeSource packages (`curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -` then `sudo apt-get install -y nodejs`).
- From the repo root, run `npm install` once to restore the dev-toolchain dependencies (`ajv`, `zod`, `markdownlint-cli2`, etc.). The `tools/npm/run-script.mjs` wrapper will auto-run `npm install` later if `node_modules` is missing, but priming the cache keeps diagnostics quiet.
- Compile the shared TypeScript helpers (watchers, schema generators, CLI helpers) with `npm run build`. Re-run this command anytime files under `src/tools/**/*.ts` change; scripts that rely on the compiled artifacts (for example `Run-SessionIndexValidation.ps1`) also auto-trigger `npm run build` when `dist/` is stale.
- Importing a SemVer bundle from another repo? After copying the files, run `pwsh -File tools/Verify-SemverBundle.ps1 -BundlePath <bundle-folder-or-zip>` to confirm the hashes in `bundle.json` match what landed in your workspace.

### Installing PowerShell on Ubuntu/WSL
Ubuntu images created by WSL do not include PowerShell by default, but the coverage and packaging stages rely on `pwsh`. From your WSL shell:

```bash
cd /mnt/c/codex/home/runner/work/icon-editor-lab
sudo apt-get update
sudo apt-get install -y wget apt-transport-https software-properties-common
wget -q https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install -y powershell
pwsh --version
```

Swap `22.04` for your distro codename if you’re not on Jammy. After installation, `pwsh` lives on your PATH so local CI stages can launch it directly.

## VS Code Tasks
Open the repo in VS Code and run any of the following from the Command Palette → “Tasks: Run Task”:
- Local CI: Ubuntu (all stages)
- Local CI: Ubuntu (docker + tests)
- Local CI: Ubuntu (watch Windows publish)
- Local CI: Windows (all stages)
- Local CI: Windows (fast, skip signing)
- Verify LV Env (snapshot)
- Repair LV Env (display dependencies)
- Repair LV Env (apply VIPC)

The “Repair LV Env” tasks wrap `src/tools/icon-editor/Invoke-VipmDependencies.ps1`. Display mode lists the VIPM packages expected; apply mode installs from a `.vipc` you provide.

## Recommended Flow
1) Ubuntu pre-checks: run “Local CI: Ubuntu (docker + tests)” to verify schema, smoke tests, and container tools.
2) Capture the Ubuntu manifest: the “Local CI: Ubuntu (all stages)” task emits `out/local-ci-ubuntu/<timestamp>/ubuntu-run.json`. That folder also contains `local-ci-artifacts.zip`, which Windows imports for determinism.
3) Windows fast path: run “Local CI: Windows (fast, skip signing)” to stage artifacts and run Pester, or use the canonical handshake tasks:
   - “Local CI: Windows (import Ubuntu run)” for a prompted path.
   - “Local CI: Windows (auto-import latest Ubuntu run)” to automatically pick the newest folder under `out/local-ci-ubuntu/` and invoke LabVIEW immediately.
   - Need fully automatic behavior? Start “Local CI: Windows (watch Ubuntu runs)” (or schedule `local-ci/windows/watchers/Watch-UbuntuRuns.ps1`) so every new Ubuntu run kicks off LabVIEW without manual steps.
   - Want Ubuntu to refresh reports the moment Windows publishes? Pair the Windows watcher with “Local CI: Ubuntu (watch Windows publish)” (wrapper around `local-ci/ubuntu/watchers/watch-windows-vi-publish.sh`), which tails `out/vi-comparison/windows/**/publish.json` and re-runs stage 45 whenever new LabVIEW outputs land.
   - Sentinels keep the handshake deterministic: Ubuntu marks `<run>/_READY`, the Windows watcher claims the run (`windows.claimed`), stage 37 drops `<run>/windows/vi-compare.publish.json`, and Ubuntu stage 45 writes `<run>/_DONE` once it finishes rendering. Feel free to clean up stale runs by removing these files if you need to re-run the pipeline.
   - Prefer a single command? From Windows PowerShell run `pwsh -File local-ci/scripts/Invoke-FullHandshake.ps1`. It will (a) start the Ubuntu pipeline inside WSL, (b) run the Windows import/LabVIEW stages, and (c) call back into WSL to render stage 45, leaving you with `_DONE` plus the HTML/Markdown output. Use `-SkipUbuntu`, `-SkipWindows`, or `-SkipRender` if you want to exercise only parts of the flow.
   - **Bridge scenarios**
     | Scenario | Command | When to use |
     | --- | --- | --- |
     | Full Bridge | `pwsh -File local-ci/scripts/Invoke-FullHandshake.ps1` | Run Ubuntu → Windows → Ubuntu for complete verification. |
     | Windows retry | `pwsh -File local-ci/scripts/Invoke-FullHandshake.ps1 -SkipUbuntu` | Retry Windows stages after the Ubuntu run already produced `_READY`. |
     | Renderer-only | `pwsh -File local-ci/scripts/Invoke-FullHandshake.ps1 -SkipUbuntu -SkipWindows` | Re-render stage 45 from an existing publish when touching documentation or renderer logic. |
     | Watcher loop | `bash local-ci/ubuntu/watchers/watch-windows-vi-publish.sh` | Let Ubuntu watch the Windows publish directory for continuous replay instead of a single command. |
4) Verify LV env: run “Verify LV Env (snapshot)” to confirm LabVIEW/LVCompare/LabVIEWCLI/VIPM paths and versions. Snapshot is saved under `out/windows-lvenv/<timestamp>/lv-env.snapshot.json`.
5) Repair LV environment: ensure VIPM is running, then run “Repair LV Env (apply VIPC)” and point to your `.vipc` file (e.g., `.github/actions/apply-vipc/runner_dependencies.vipc`).
6) Full Windows run: “Local CI: Windows (all stages)” (includes signing if configured).

## Notes
- If you need to adjust Pester tags for Ubuntu runs, update `local-ci/ubuntu/config.yaml`.
- Docker cache knobs and details are in `docs/local-ci-runner.md` (buildx cache, remote image, push/pull helpers).
- Optional import toggles: `LOCALCI_IMPORT_SKIP_GITCHECK=true` bypasses the git SHA guard (only use when intentionally diverging), and `LOCALCI_IMPORT_NO_EXTRACT=true` keeps the ZIP untouched if you solely need the manifest metadata.
- If VIPM is not running, the apply step will fail fast; you can run the “display” task to confirm dependencies first.
- VI comparison flow is two-step: Windows publishes raw LabVIEWCLI outputs to `out/vi-comparison/windows/<windows_stamp>`, and Ubuntu stage 45 consumes those when available (falling back to the dry-run payload otherwise). Adjust the behavior via `vi_compare.requests_template`, `vi_compare.windows_publish_root`, and `vi_compare.dry_run`.
- Stage 37’s LabVIEW CLI run is configurable via `EnableViCompareCli` et al in `local-ci/windows/profile.psd1`. Toggle per run with `LOCALCI_VICOMPARE_CLI_ENABLED=true|false` and fall back to stub generation with `LOCALCI_VICOMPARE_FORCE_DRYRUN=true`.
