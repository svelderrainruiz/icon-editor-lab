# Local CI Runner Design (Windows & Ubuntu)

## Goals
- Provide a deterministic, single-command workflow that mirrors `.github/workflows/ci-windows-signed.yml` and `ci-ubuntu-minimal.yml`.
- Allow fork owners (and this “golden” Windows box) to validate changes offline before touching GitHub Actions.
- Capture transcripts/artifacts under `out/` so results can be compared with hosted runners.
- Keep the design script-first (PowerShell on Windows, Bash on Ubuntu) so it can eventually be promoted into an Actions job.

## High-Level Architecture
```
local-ci/
  windows/
    Invoke-LocalCI.ps1  (top-level orchestrator)
    stages/
      10-Prep.ps1      (checkout verification, env guard, log dirs)
      20-Build.ps1     (repo build → SIGN_ROOT=out/)
      25-DevMode.ps1   (ensure LabVIEW dev-mode matches profile action)
      30-Tests.ps1     (Invoke-RepoPester.ps1 with tags=tools,scripts,smoke)
      40-Signing.ps1   (wraps scripts/Test-Signing.ps1 switches)
      50-Pack.ps1      (Hash-Artifacts.ps1, optional artifact zip)
    profile.psd1        (YAML/PSD1 to toggle stages, timeouts, tags)
  ubuntu/
    invoke-local-ci.sh
    stages/
      10-prep.sh
      20-build.sh
      25-docker.sh
      28-docs.sh       (local markdown link checker + markdownlint in Docker)
      30-tests.sh      (pwsh -File scripts/Invoke-RepoPester.ps1 -Tag smoke,linux)
      35-coverage.sh   (Pester run w/ Cobertura + threshold enforcement)
      40-package.sh    (Hash-Artifacts.ps1 or sha256sum)
    config.yaml
```

Each orchestrator:
1. Loads configuration (default + overrides from env vars/flags).
2. Emits a run header (UTC timestamp, git SHA, branch, machine info).
3. Executes numbered stage scripts in order, honoring `--skip <stage>` / `--only <stage>`.
4. Streams each stage's transcript to `out/local-ci/<timestamp>/stage-XX.log`.
5. Exits non-zero immediately on stage failure.

## Implementation Plan

### Windows Flow
1. **Profile loading** – parse `local-ci/windows/profile.psd1`, merge CLI/env overrides, and compute the bitness plan/IDs (`<version>-<bitness>`). During this step resolve the actual LabVIEW installation path for each `(version, bitness)` pair (via `Find-LabVIEWVersionExePath`) so stages receive a concrete “revision descriptor” at runtime. Persist the plan to the run context so downstream stages can reuse both the ID and resolved paths.
2. **Stage harness** – implement a runner helper that iterates through the ordered stage list (`@('10-Prep','20-Build',...)`), passing the shared context and current bitness entry (for stages flagged as `PerBitness = $true`).
3. **Stage scripts** – update/author each script under `local-ci/windows/stages/` to accept `-Context` and optional `-BitnessId`. Stages 25, 30, 35, 36, and 37 consume the bitness ID; the rest ignore it.
4. **Artifact layout** – ensure per-bitness outputs land under `out/local-ci/<stamp>/<stage>/<bitnessId>` or the stage-specific path noted in the table.
5. **Cleanup and reporting** – stage 55 (dev-mode cleanup) and post-run summary logic read the stored bitness IDs to reverse earlier enablement and to emit a consolidated JSON manifest.

### Linux Flow
1. **Config bootstrap** – extend `local-ci/ubuntu/config.yaml` with any new knobs (tags, bitness once needed). The shell runner reads the YAML and exports env vars (`LABVIEW_VERSION`, `LABVIEW_BITNESS`, etc.), then dynamically probes the LabVIEWCLI install to confirm the requested revision/bitness exists before proceeding (or bails with guidance).
2. **Stage dispatcher** – keep the existing numbered scripts but wrap them in a `run_stage()` helper inside `invoke-local-ci.sh` that logs start/stop events and aborts on failure, mirroring the Windows harness.
3. **Stage updates** – verify stages `10-prep.sh` through `40-package.sh` honor the exported env vars and write results into `out/local-ci/<stamp>/ubuntu/<stage>.log`. Add placeholders for future bitness fan-out (e.g., `LABVIEW_BITNESS_LIST=${LABVIEW_BITNESS_LIST:-64}` loops).
4. **Cross-OS handshake** – ensure stage 40 packages the artifacts expected by Windows (vi-comparison payloads, publish markers) and that it records the run metadata Windows needs (package path, SHA, tag list).
5. **Documentation & tasks** – update VS Code tasks / scripts to call the orchestrators, and document any new env vars or log locations so contributors can reproduce the pipeline.

## Docker Ubuntu Runner

Stage `25-docker.sh` now builds two Docker images:

1. `icon-editor-lab/tools:local-ci` – the base tooling image used by CI to lint, run coverage, and validate provider/test intent.
2. `icon-editor-lab/ubuntu-runner:local-ci` – a derived image with the `/usr/local/bin/localci-run-handshake` entrypoint.

The Ubuntu runner image allows you to execute the full Ubuntu pipeline locally without depending on GitHub:

```bash
# After running Stage 25 once to build the image tags
docker run --rm \
  -v "$PWD:/work" \
  icon-editor-lab/ubuntu-runner:local-ci \
  localci-run-handshake --skip 28-docs --skip 30-tests
```

The command assumes your repository is mounted at `/work`, and any `invoke-local-ci.sh` flags (e.g., `--only 35-coverage`) can be appended. A matching VS Code task `Local CI: Ubuntu (docker runner)` is provided to simplify invocation.

The Windows consumer still executes natively on the same Windows box hosting Docker Desktop, so LabVIEW/TestStand automation remains unchanged. The Docker runner simply provides a deterministic Ubuntu environment for local experimentation.

### Scheduling VI Rendering After Windows Publish

Both the repository and the Ubuntu runner image now include `tools/local-ci/Schedule-ViStage.ps1`. This helper inspects `vi-comparison-summary.json` (produced after the Windows job publishes results) and, when it detects any changed/new VI pairs, re-runs the Ubuntu rendering stages (`45-vi-compare` and `40-package`).

Usage (native):

```powershell
pwsh -File tools/local-ci/Schedule-ViStage.ps1 -Stamp 20251114-000040 -DryRun
pwsh -File tools/local-ci/Schedule-ViStage.ps1 -Stamp 20251114-000040
```

Usage (Docker):

```bash
docker run --rm \
  -v "$PWD:/work" \
  icon-editor-lab/ubuntu-runner:local-ci \
  pwsh -File /opt/local-ci/Schedule-ViStage.ps1 -RepoRoot /work -Stamp 20251114-000040
```

Invoke this helper after the Windows consumer writes `windows/vi-compare.publish.json`. When the summary shows no changes it exits quietly; otherwise it triggers the renderer so reports stay in sync without waiting for a full Ubuntu rerun.

## Self-Hosted Windows Runner Baseline

The “golden” Windows box that drives stage 25/30/37/40 must look the same as the GitHub Actions self-hosted runner we recommend to downstream forks. Keeping the hardware and software baselines in sync avoids LabVIEW drift, removes PSGallery dependence during runs, and ensures Stage 40 can reach the certificate store without interactive prompts.

### Hardware profile
- **Chassis**: Windows 11 Pro/Enterprise 23H2 or Windows Server 2022 Standard (64-bit) with virtualization enabled but Hyper-V features disabled during LabVIEW sessions. Keep Secure Boot on and turn off hibernation so scheduled runs are predictable.
- **CPU**: ≥8 physical cores / 16 threads (recent Intel i7/i9 or Ryzen 7/9). LabVIEW CLI and VICompare both spike CPU usage when multiple bitness plans are active; fewer cores drag VI opens and force longer gating windows.
- **Memory**: ≥32 GiB RAM (64 GiB preferred) so LabVIEW 2021 + LabVIEW 2025 preview + VIPM can co-exist with pwsh/Node/Python tooling without paging.
- **Storage**: ≥1 TB NVMe SSD dedicated to builds. Reserve at least 200 GiB free for `out/local-ci/<stamp>`, cached VIPCs, and crash dumps. Put the repository under an NTFS volume with long-path support and leave Windows Defender exclusions for `out/` and `%TEMP%\LabVIEW`.
- **Networking**: Wired gigabit with outbound 443 access to GitHub, Digicert TSA, PSGallery, and NI download mirrors. Maintain clock sync (w32tm) so timestamp enforcement stays valid.

### Software stack
- **PowerShell**: Install PowerShell 7.4.x (x64) system-wide and ensure `pwsh.exe` is first in `PATH`. Preconfigure the execution policy to `RemoteSigned` and trust PSGallery so Stage 10 never prompts for consent.
- **LabVIEW**: Install LabVIEW 2021 64-bit plus LabVIEW CLI (`C:\Program Files\National Instruments\LabVIEW 2021\LabVIEW.exe` and `%ProgramFiles(x86)%\National Instruments\Shared\LabVIEW CLI\LabVIEWCLI.exe`) to satisfy the default `labview-2021-x64` profile. Stage 37’s VICompare helpers also probe `C:\Program Files\National Instruments\LabVIEW 2025\LabVIEW.exe`; keep that preview build patched even if it only feeds compare capture experiments. Register G‑CLI in `PATH` so `g-cli` resolves without a fully qualified path.
- **VIPM**: Install JKI VIPM 2023.1 or newer with CLI support and sign in with a license that can import `.vipc` files. Configure the app once with the service account so Stage 45 can run headless.
- **Pester/Test tooling**: Pre-install Pester 6.x (`Install-Module Pester -Scope CurrentUser -RequiredVersion 6.0.0`) and the supporting modules (ThreadJob) because PSGallery downloads are frequently throttled on corporate firewalls. Verify `Invoke-Pester -Configuration (New-PesterConfiguration)` succeeds before the runner claims jobs.
- **Runtime dependencies**: Keep .NET Desktop Runtime 7.x, the Visual C++ 2015–2022 redistributable, Node.js 20 LTS, and Python 3.11+ on the path so Markdown renderers, coverage summarizers, and CLI shims work the same as the hosted Ubuntu stages.
- **Code-signing certificates**: Import the real signing certificate(s) into the service account’s `CurrentUser\My` store and grant the runner identity permission to use the private key. Stage 40’s harness looks for certificates via `scripts/Test-Signing.ps1`, so document the thumbprint in the runner secrets (e.g., `LOCALCI_SIGN_CERT_THUMBPRINT`) and maintain a backup `.pfx` in a secure vault. Add the Digicert RFC‑3161 TSA endpoint to the outbound allow list.
- **Accounts & automation**: Run the GitHub Actions service (`actions-runner`) under a dedicated local admin account with `Log on as a service`, and pre-create `C:\local-ci` / `C:\ProgramData\local-ci` so runs do not compete with Desktop redirection. Configure Windows Update’s maintenance window outside CI hours and snapshot the machine after every LabVIEW patch cycle.
- **Provisioning automation**: Run `local-ci/windows/scripts/Provision-LocalRunner.ps1` as administrator (optionally with `-UseChocolatey` when winget is unavailable) to install PowerShell 7.4, Node.js 20 LTS, Python 3.11+, and the needed PowerShell modules. Provide `-SigningCertPath`/`-SigningCertPassword` for the code-sign certificate import and reuse `-RunnerRoot C:\local-ci` so the handshake workflow sees the same artifact layout. This script brings the host to parity before you register it with labels `[self-hosted, Windows, X64]` (or whatever label set your org standardizes on for LabVIEW-capable Windows runners).
- **Provisioning automation**: Run `local-ci/windows/scripts/Provision-LocalRunner.ps1` as administrator (optionally with `-UseChocolatey` when winget is unavailable) to install PowerShell 7.4, Node.js 20 LTS, Python 3.11+, and the needed PowerShell modules. Provide `-SigningCertPath`/`-SigningCertPassword` for the code-sign certificate import and reuse `-RunnerRoot C:\local-ci` so the handshake workflow sees the same artifact layout. This script brings the host to parity before you register it with labels `[self-hosted, Windows, X64]` (or whatever label set your org standardizes on for LabVIEW-capable Windows runners). When a different label set is required, set the repository/organization variable `LOCALCI_WINDOWS_RUNS_ON` to a JSON array (e.g., `["self-hosted","Windows","X64","local-ci"]`) so the workflow uses the correct `runs-on` target without further edits.

## Sequence & Bitness Layer

Both orchestrators treat a “sequence” as an ordered list of stage definitions that are grouped per operating system. Each stage can fan out further across LabVIEW bitness variants, so a single logical stage (for example, “Enable DevMode”) might run twice: once for 32-bit and once for 64-bit.

- **Windows sequence** – `Invoke-LocalCI.ps1` reads `profile.psd1`, expands `LabVIEWVersion`/`LabVIEWBitness` into a bitness plan, and then executes the following logical pipeline for each requested bitness (default `@(64)` but profiles such as reliability or build-package expand it to `@(32,64)`). Each bitness entry gets a unique ID of the form `<version>-<bitness>` (e.g., `2023-32`, `2023-64`) so per-bitness artifacts can be correlated across stages.

  | Stage | Runs per bitness? | Description |
  | --- | --- | --- |
  | `10-Prep` | no | Machine prep is identical regardless of bitness. |
  | `20-Build` | no | Build artifacts do not change with LabVIEW bitness. |
  | `25-DevMode` | yes | Calls `Enable-DevMode.ps1` once per bitness; records the active bitness list so Stage 55 can disable each entry. |
  | `30-Tests` | optional | Tag-driven tests; when tags include LabVIEW-specific suites the stage loops through the bitness list, passing `-LabVIEWBitness` to the runner. |
  | `35-Validation` / `36-LUnit` / `37-VICompare` | yes | Validation, LUnit, and VICompare stages read `LabVIEWBitness` from the bitness plan so they can run the MissingInProject suite or TestStand harness against each target. |
  | `40+` (signing, packaging, cleanup) | no | These stages aggregate outputs from earlier stages, so they run once after the per-bitness work finishes. |

  The fan-out logic looks roughly like:

  ```powershell
  $bitnessPlan = if ($config.LabVIEWBitness) { @($config.LabVIEWBitness) } else { @(64) }
  foreach ($bitness in $bitnessPlan) {
      $bitnessId = "{0}-{1}" -f $config.LabVIEWVersion, $bitness
      Invoke-Stage25 -Bitness $bitness -BitnessId $bitnessId
      Invoke-Stage35 -Bitness $bitness -BitnessId $bitnessId
      # ...
  }
  ```

- **Ubuntu sequence** – the bash orchestrator currently targets 64-bit LabVIEWCLI only, so the bitness plan is a singleton. The same “sequence” abstraction still applies; when we eventually add 32-bit Ubuntu coverage the stage scripts already accept `LABVIEW_BITNESS`, so the orchestrator can loop just like Windows.

Framing the runner as “per-OS sequences with optional bitness variants” keeps the mental model consistent: add a stage to the Windows sequence, decide whether it needs per-bitness execution, and the orchestrator will expand it automatically based on the profile.

## Windows Flow (PowerShell 7)
| Stage | Responsibilities | Implementation Notes |
| --- | --- | --- |
| 10-Prep | Ensure PS 7 + required modules (ThreadJob, Pester), verify repo cleanliness (opt-in), validate LabVIEW/G CLI parity via `Test-EnvironmentParity.ps1`, create `out/local-ci/<stamp>` directories, clear `SIGN_ROOT` contents except `local-signing-logs/`. | Reuse `tools/EnvGuard.psm1` if available; parity manifest lives at `local-ci/windows/env-profiles.psd1`. |
| 20-Build | Run real build entry point (e.g., `pwsh -File scripts/build.ps1 -Configuration Release -Out out/`). Until build exists, call placeholder that copies sample payloads into `out/`. | Expose `-SkipBuild` flag for scripting scenarios. |
| 25-DevMode | Auto-vendor (when configured) and enable LabVIEW development mode based on profile config (`DevModeAction`, version/bitness overrides). | Runs `local-ci/windows/scripts/Sync-IconEditorVendor.ps1` when `vendor/labview-icon-editor` is missing, then calls `Enable-DevMode.ps1` once per bitness ID (`<version>-<bitness>`). When `DevModeDisableAtEnd` is `$true`, Stage 25 always enables dev mode (even if the config requested `Disable`) and records the per-bitness IDs so Stage 55 performs the disable step; rogue-LabVIEW logs are written under `out/local-ci/<stamp>/devmode/rogue/<bitnessId>`. Stage 25 now attempts a graceful g-cli/LabVIEWCLI shutdown via `Close-LabVIEW.ps1` before enabling; only when `DevModeAllowForceClose` (or `LOCALCI_DEV_MODE_FORCE_CLOSE=1`) is set and the graceful attempt fails will it fall back to `Force-CloseLabVIEW.ps1`. |
| 30-Tests | Execute `scripts/Invoke-RepoPester.ps1` with configurable tags: default `tools,scripts,smoke`. Allow `-AdditionalTag windows` for parity with Actions filters. | When the profile requests multiple bitness values, the runner invokes the test stage once per bitness ID and folds the JUnit output into `out/test-results/local-ci-pester-<bitnessId>.xml` before aggregating. |
| 35-Validation | Optional gate (when `EnableValidationStage` is true) that runs the MissingInProject validation suite (`Invoke-MissingInProjectSuite.ps1`) with the configured `.viancfg`, LabVIEW version, and bitness. | Validation outputs land under `tests/results/<label>/<bitnessId>` with `_agent/reports/missing-in-project/<label>-<bitnessId>.json`. |
| 36-LUnit | Optional MipLunit/LUnit scenario (controlled by `EnableMipLunitStage`) that executes `Run-MipLunit-20xx.ps1` and emits integration summaries for Scenario 6a/6b. | Produces `_agent/reports/integration/<bitnessId>-*.json` and LUnit/missing-in-project artifacts under `tests/results/<bitnessId>`. |
| 37-VICompare | Consume the imported `vi-comparison/<stamp>` payload from Ubuntu, run LabVIEWCLI/TestStand (or stub) to produce raw captures, and copy the results to `out/vi-comparison/windows/<windows_stamp>/<bitnessId>` with a `publish.json` summary. | Serves as the handshake back to Ubuntu so the renderer can operate without LabVIEW; the bitness ID helps the renderer pick the correct publish set. |
| 40-Signing | Wrap `scripts/Test-Signing.ps1` but add more knobs: `-ToolsOnly`, `-ScriptsOnly`, `-SkipHarness`, `-SimulateTimestampFailure`. Export summary JSON (counts, avg ms, failures). | Stage summary saved to `out/local-ci/<stamp>/signing-summary.json` with per-bitness context embedded when earlier stages produced multiple IDs. |
| 45-VIPM | Optional VIPM dependency repair stage (`EnableVipmStage`) that runs `local-ci/windows/scripts/Repair-LVEnv.ps1` in display or apply mode. | Ensures `.vipc` dependencies are applied locally before analyzer/LUnit stages. |
| 50-Pack | Run `tools/Hash-Artifacts.ps1` if `out/` contains binaries/scripts. Optionally zip the signed payload into `out/local-ci/<stamp>/signed-artifacts.zip`. | Useful for manual transfer or replays. |
| 55-DevModeCleanup | When `DevModeDisableAtEnd` is true, call `Disable-DevMode.ps1` using the versions/bitness recorded by Stage 25 so LabVIEW exits the run in a clean state. | Reads the `dev-mode-marker.json` marker under `out/local-ci/<stamp>`; skips if the marker is missing or cleanup is disabled. |

**Artifacts & Telemetry**
- Root ledger: `out/local-ci/<stamp>/run-metadata.json` (git SHA, branch, runner type, stage durations).
- Stage-specific transcripts already exist for signing; extend the same pattern across stages.
- Provide summary banner at the end with counts (tests run, scripts signed, artifacts produced).

## Ubuntu Flow (Bash + PowerShell Core)
Ubuntu runner mirrors the stage model but swaps PowerShell for Bash where natural:

1. **10-prep.sh** – verifies `pwsh`, `gh`, `dotnet`/`node` (if needed), ensures `out/` exists, cleans stage dir.
2. **20-build.sh** – runs the Linux build (currently placeholder). Emits artifacts into `out/`.
3. **25-docker.sh** – builds `src/tools/docker/Dockerfile.tools` into a local tag (`icon-editor-lab/tools:local-ci` by default) and runs a container smoke test (`node`, `pwsh`, `python3`). Before building it optionally pulls `ghcr.io/svelderrainruiz/icon-editor-lab/tools:local-ci` (configurable via `LOCALCI_DOCKER_REMOTE_IMAGE`) so the cache layers stay warm, and when `LOCALCI_DOCKER_PUSH_REMOTE=true` it tags/pushes the freshly built image back to the registry (assuming you ran `docker login`). Ensures Docker prerequisites are satisfied before later stages.
4. **28-docs.sh** – local-only markdown link checker (Python) that respects `docs_stage.allow_missing` and `docs_stage.allow_missing_globs`, then `markdownlint` via `node:20-alpine`. Both operations can be disabled independently.
5. **30-tests.sh** – executes `pwsh -File scripts/Invoke-RepoPester.ps1` with the configured tag list (default `smoke,linux,tools,scripts`); JUnit output lands in `out/test-results/pester.xml`.
6. **35-coverage.sh** – reruns Pester with Cobertura output and enforces `coverage.min_percent`. Honors `coverage.tags` or `LOCALCI_COVERAGE_TAGS` and fails fast when PowerShell 7 is missing from the Ubuntu/WSL host.
7. **40-package.sh** – reuses `tools/Hash-Artifacts.ps1` via `pwsh` or uses native `sha256sum`, then writes `out/local-ci-ubuntu/<stamp>/ubuntu-run.json` which captures git metadata, stage logs, coverage %, and the relative path to `local-ci-artifacts.zip`. This manifest is the handshake token for the Windows runner.
8. **45-vi-compare.sh** – looks for a Windows `publish.json` under `vi_compare.windows_publish_root`, copies the real LabVIEWCLI outputs back into the current run, and re-renders Markdown/HTML via the Ubuntu renderer. If no publish is available yet, it falls back to the dry-run payload so the run stays deterministic. In both cases the rendered artifacts land under `out/local-ci-ubuntu/<stamp>/vi-comparison/` and are mirrored to `out/vi-comparison/<stamp>/`.

On Ubuntu the signing step is skipped (matching `ci-ubuntu-minimal.yml`). Instead, we verify `out/` manifests by hashing and comparing with `Hash-Artifacts.ps1`, plus publish Cobertura + JUnit artifacts from the coverage stage.

## Configuration Surface
| Setting | Windows default | Ubuntu default | Description |
| --- | --- | --- | --- |
| `SIGN_ROOT` | `out` | `out` | Shared staging path |
| `LOCAL_CI_TAGS` | `tools,scripts,smoke` | `smoke,linux,tools,scripts` | Pester tag list |
| `MAX_SIGN_FILES` | `500` | n/a | Passed into signing helper |
| `TIMESTAMP_TIMEOUT_SEC` | `25` | n/a | Fed to `Test-Signing.ps1` |
| `SKIP_STAGES` | `()` | `()` | List of stage IDs to bypass |
| `STOP_ON_UNSTAGED_CHANGES` | `false` | `false` | Guard rail before running |

Configurations live in:
- `local-ci/windows/profile.psd1`
- `local-ci/ubuntu/config.yaml`

Each orchestrator loads defaults, then merges environment overrides (e.g., `LOCAL_CI_TAGS="tools,scripts,windows"`).

For the Docker stage you can set:
- `LOCALCI_DOCKER_REMOTE_IMAGE` to change the registry target (default `ghcr.io/svelderrainruiz/icon-editor-lab/tools:local-ci`)
- `LOCALCI_DOCKER_PULL_REMOTE=false` to skip pulling that image before building
- `LOCALCI_DOCKER_PUSH_REMOTE=true` to tag/push the local build back to the registry after `docker login`
- `LOCALCI_DOCKER_USE_BUILDX=true` to build with `docker buildx` and export cache to a registry while still loading the image locally
- `LOCALCI_DOCKER_CACHE_REF` to override the buildx cache reference (defaults to `<remote_repo>:buildcache`)
- `LOCALCI_DOCKER_SKIP_PREFLIGHT=true` to skip the GHCR network preflight check

Use `local-ci/ubuntu/scripts/refresh-docker-cache.sh` to prefetch the remote image before running any stages (or as part of your shell login) so every run starts with the warmed layers without rebuilding.

When you want to publish the cache image back to your registry (e.g., GHCR) with resilience, use `local-ci/ubuntu/scripts/push-docker-cache.sh` which performs a tag + push with exponential backoff retries and a GHCR preflight. The Docker stage automatically uses this helper when `LOCALCI_DOCKER_PUSH_REMOTE=true`.

Docs + coverage knobs:
- `docs_stage.check_links` / `docs_stage.markdownlint` toggle each half of stage 28, while `docs_stage.allow_missing` (exact paths) and `docs_stage.allow_missing_globs` (patterns) extend the baked-in allowlist for still-in-flight files like `ENVIRONMENT.md`. Stage 10 now also verifies the Ubuntu host has `pwsh`, `python3`, `zip`, and installs Pester/ThreadJob automatically so later stages do not fail mid-run.
- `coverage.tags` lets you narrow the Cobertura run to a custom set of Pester tags; when omitted the stage reuses the global `pester_tags`.
- `coverage.enabled` disables stage 35 entirely, `coverage.min_percent` enforces the Cobertura threshold (default 75), and `coverage.tags` (or env `LOCALCI_COVERAGE_TAGS`) narrow the Pester filter if you only want a subset of tests contributing to the coverage gate. When `coverage.tags` is omitted, the runner reuses the general Pester tags from `local-ci/ubuntu/config.yaml`.
- `vi_compare.enabled` toggles stage 45, `vi_compare.dry_run` controls whether `Invoke-FixtureViDiffs.ps1` uses the dry-run path, `vi_compare.requests_template` can point at a custom `vi-diff-requests.json`, and `vi_compare.windows_publish_root` tells Ubuntu where to look for the Windows `publish.json` summaries (default `out/vi-comparison/windows`). When no Windows publish is found, the stage falls back to the dry-run payload so runs remain deterministic.

### Ubuntu → Windows Handshake
1. Every successful Ubuntu run drops `ubuntu-run.json` next to the logs plus `local-ci-artifacts.zip` that contains the hashed payload (`checksums.sha256` is bundled).
2. On Windows, stage 10 loads `local-ci/windows/scripts/Import-UbuntuRun.psm1` and, when `LOCALCI_IMPORT_UBUNTU_RUN` is set (directory or manifest path), it:
   - Parses the manifest, validates the git SHA (unless `LOCALCI_IMPORT_SKIP_GITCHECK=true`), and confirms `local-ci-artifacts.zip` exists by combining the repo root with `paths.artifact_zip_rel`.
   - Expands the archive into `<runRoot>/ubuntu-artifacts` (or skips extraction when `LOCALCI_IMPORT_NO_EXTRACT=true`) and writes `ubuntu-import.json` for traceability.
3. VS Code exposes two canonical tasks for the Windows side:
   - **Local CI: Windows (import Ubuntu run)** prompts for a specific folder or manifest path.
   - **Local CI: Windows (auto-import latest Ubuntu run)** calls `local-ci/windows/scripts/Start-ImportedRun.ps1`, which automatically selects the most recent folder under `out/local-ci-ubuntu/` and invokes `Invoke-LocalCI.ps1` with `LOCALCI_IMPORT_UBUNTU_RUN` set. This is the recommended “one click” handshake to kick off the first LabVIEW stage immediately after the Ubuntu run finishes.
   - For a single-run demo without background watchers, use `pwsh -File local-ci/scripts/Invoke-FullHandshake.ps1` from Windows. It starts the Ubuntu pipeline via WSL, runs the Windows stages, and then re-enters WSL to execute stage 45 with the fresh publish. Flags like `-SkipUbuntu` / `-SkipRender` let you resume at any point.

The import helper has focused Pester coverage (`tests/local-ci/Import-UbuntuRun.Tests.ps1`) to ensure regressions in the manifest parser or ZIP extraction are caught locally before promoting to CI.

Each run also emits sentinel files that keep the multi-plane handshake deterministic:
- Ubuntu writes `<run>/_READY` after the manifest/artifact ZIP is finalized.
- The Windows watcher refuses to touch runs without `_READY`, writes `<run>/windows.claimed` when it starts the import, and leaves the JSON behind so downstream tooling can tell which machine picked up the work.
- Stage 37 removes `_READY`, copies the publish summary to `<run>/windows/vi-compare.publish.json`, records `_PUBLISHED.json`, and updates `windows.claimed` with the Windows run stamp.
- Ubuntu stage 45 writes `<run>/_DONE` once it re-renders with the real LabVIEW outputs. These breadcrumbs mean you can safely mount the same `out/` folder from multiple machines without reprocessing or guessing about state.

### Watcher Mode (Windows)
When you want LabVIEW stages to start automatically the moment Ubuntu finishes, enable the watcher:

1. Run `pwsh -NoLogo -NoProfile -File local-ci/windows/watchers/Watch-UbuntuRuns.ps1` (or the VS Code task “Local CI: Windows (watch Ubuntu runs)”).  
2. The watcher polls `out/local-ci-ubuntu/` for new folders containing `ubuntu-run.json`. For every unseen run it:
   - Logs metadata to `out/local-ci-windows/watchers/<timestamp>/watcher.log`.
   - Invokes `local-ci/windows/scripts/Start-ImportedRun.ps1 -UbuntuRunPath <folder>`, which sets `LOCALCI_IMPORT_UBUNTU_RUN` and runs the standard Windows stages.
   - Emits a summary JSON (`watcher-summary.json`) capturing the manifest, timestamps, and the exit code from the LabVIEW run—handy for troubleshooting. Stage 37 then copies the raw VI comparison outputs to `out/vi-comparison/windows/<windows_stamp>` so Ubuntu can consume them later.
   - Only runs with `_READY` present and no `windows.claimed` file are considered; the watcher writes `windows.claimed` (JSON payload) before launching LabVIEW so other machines know the run is taken.
3. Run in `-Once` mode for ad-hoc debugging, or add a Task Scheduler entry so the watcher runs continuously on the LabVIEW box after each reboot/logon.

Because all watcher output lives under `out/local-ci-windows/watchers/`, you can quickly inspect which Ubuntu run triggered the current LabVIEW session and correlate its logs if the Windows stages fail.

### Watcher Mode (Ubuntu)
The return trip (Ubuntu consuming freshly published Windows artifacts) can also be automated:

1. Run `bash local-ci/ubuntu/watchers/watch-windows-vi-publish.sh` (or the VS Code task “Local CI: Ubuntu (watch Windows publish)”). The script first looks for `<run>/windows/vi-compare.publish.json` (which stage 37 now writes) and falls back to the global `out/vi-comparison/windows/**/publish.json` directory when needed.
2. Options of note:
   - `--windows-root <path>` overrides the publish root (defaults to `out/vi-comparison/windows`).
   - `--run <ubuntu_stamp>` locks the watcher to a single Ubuntu payload.
   - `--once` processes pending publishes once and exits, while the default loop sleeps `--interval` seconds between scans (30s by default). `--dry-run` logs intended actions without invoking stage 45.
   - `--state-dir` / `--log-dir` (default `out/local-ci-ubuntu/watchers`) control where `vi-publish-state.json` and `vi-publish-watcher.log` are written.
3. When a new publish is detected, the watcher sets `LOCALCI_WINDOWS_PUBLISH_JSON` and reruns stage 45 so Markdown/HTML renders are refreshed immediately, even if multiple Windows runs land between Ubuntu iterations. Stage 45 writes `<run>/_DONE` when the real LabVIEW artifacts have been ingested, which prevents the Windows watcher from re-queuing the same run later.

Because logs live under `out/local-ci-ubuntu/watchers/`, it is easy to correlate which Windows publish was ingested and whether the re-render succeeded.

### Windows → Ubuntu Return Path
After stage 37 completes, the Windows runner now copies the raw VI comparison outputs (requests, summary, LVCompare captures) to `out/vi-comparison/windows/<windows_stamp>` and writes a `publish.json` with `schema = 'vi-compare/publish@v1'`. Ubuntu stage 45 looks for matching publish files (based on the Ubuntu run stamp) under `vi_compare.windows_publish_root`, copies the real artifacts back into the current run directory, and re-renders Markdown + HTML using the same renderer the stub path uses. If no publish file exists (e.g., Windows hasn’t run yet), the stage falls back to the dry-run payload so Ubuntu runs remain deterministic.

Windows stage 37 now calls `local-ci/windows/scripts/Invoke-ViCompareLabVIEWCli.ps1` to execute each VI pair via LabVIEW CLI/TestStand:
- Config toggles in `profile.psd1`: `EnableViCompareCli`, `ViCompareLabVIEWPath`, `ViCompareHarnessPath`, `ViCompareMaxPairs`, `ViCompareTimeoutSeconds`, `ViCompareNoiseProfile`.
- Environment overrides: `LOCALCI_VICOMPARE_CLI_ENABLED` (`true/false`) and `LOCALCI_VICOMPARE_FORCE_DRYRUN` (`true` forces stub generation even when LabVIEW is present).
- The helper script emits `captures/pair-###` folders (with `lvcompare-capture.json`, `session-index.json`, `compare-report.html`) and rewrites `vi-comparison-summary.json` so Ubuntu’s renderer consumes real outputs whenever LabVIEW is available. When LabVIEW is missing, the script writes deterministic dry-run artifacts and leaves counts under `dryRun`.

Ubuntu runs now record their manifest path under `out/local-ci-ubuntu/latest.json`. The pointer contains the absolute path (`manifest`), repo-relative path (`manifest_rel`), and run-root metadata so downstream consumers can locate the freshest artifacts without guessing directory names. Stage 10 of the Windows runner checks `LOCALCI_IMPORT_UBUNTU_RUN` first, but when it is unset the new `AutoImportUbuntuRun` flag (default `true`) tells the stage to consume the pointer automatically. Advanced users can override the pointer location or the fallback search root via `UbuntuManifestPointerPath` / `UbuntuManifestSearchRoot` in `profile.psd1`, or disable the auto-detect entirely by setting `AutoImportUbuntuRun = $false`.

The GitHub Actions workflow `.github/workflows/local-ci-handshake.yml` exercises this contract end-to-end: the `ubuntu-handshake` job runs `local-ci/ubuntu/invoke-local-ci.sh` (keeping only the stages required to emit the manifest/ZIP), uploads `out/local-ci-ubuntu/<stamp>` plus `latest.json`, and the `windows-consumer` job restores those files, sets `LOCALCI_IMPORT_UBUNTU_RUN`, and invokes `local-ci/windows/Invoke-LocalCI.ps1 -OnlyStages 10,37` to confirm Stage 10 + Stage 37 ingest the Ubuntu payload without touching developer machines.

### Downstream pipeline pattern

Fork owners who maintain self-hosted Windows runners should mirror the same handshake:

1. Run `local-ci/ubuntu/invoke-local-ci.sh` (inside a hosted Ubuntu job or on-prem) to produce `out/local-ci-ubuntu/<stamp>/ubuntu-run.json` and `local-ci-artifacts.zip`.
2. Publish that directory (and `out/local-ci-ubuntu/latest.json`) as a workflow artifact so subsequent jobs can restore the pointer.
3. Before any Windows stages run, download the artifact, copy it under `out/local-ci-ubuntu/<stamp>` inside the workspace, and set `LOCALCI_IMPORT_UBUNTU_RUN` to the restored manifest path.
4. Invoke `local-ci/windows/Invoke-LocalCI.ps1` (full run or stage subsets) and optionally publish `out/local-ci/<stamp>` for troubleshooting.

Use `local-ci/scripts/New-HandshakeWorkflow.ps1 -TargetRepoRoot C:\path\to\fork` to scaffold `.github/workflows/local-ci-handshake.yml` into any downstream repo. Pass `-WindowsRunsOn '[self-hosted, windows]'` (including brackets) to preconfigure the Windows job for a self-hosted label.

### GitHub Control Plane (versioned handshake)

Relying on shared directories (`out/local-ci-ubuntu/`) assumes the Windows runner is always online to poll for new payloads. When that assumption fails, runs pile up silently. To make the handshake explicit:

- **Authoritative pointers** – After Ubuntu finishes, publish a small pointer file (`handshake/<stamp>.json`) as part of the workflow artifact or release. Include the git SHA, stamp, artifact download URL, and a monotonically increasing sequence number. Commit an aggregate `handshake/index.json` (or create/update an issue comment) listing the latest stamp. Consumers read the pointer via the GitHub API instead of scraping the filesystem.
- **Current implementation** – `local-ci-handshake.yml` now writes `handshake/pointer.json` (schema `handshake/v1`) during the Ubuntu job, uploads it as its own artifact (`handshake-pointer-<stamp>`), and later re-uploads the same artifact from the Windows job after stamping the `windows` block. Any consumer (local runner, VS Code task, scheduled job) can call `actions/download-artifact` for `handshake-pointer-*` to decide which payload to hydrate without downloading the full `out/local-ci-ubuntu` tree first.
- **Claims and leases** – When a Windows runner begins importing a stamp, write a claim record back to GitHub (e.g., `handshake/<stamp>.claim.json` or an issue comment) with the runner name and lease expiry. Other runners honor the lease before attempting the same stamp, and a watchdog expires stale leases after N minutes.
- **Status propagation** – Once Stage 37 republishes VICompare outputs, upload a `vi-publish.json` artifact and update the pointer with `windows_publish_asset_id`. Ubuntu stage 45 rehydrates the payload by following the asset reference; if the pointer lacks a publish block, it can fail fast rather than waiting for watcher side effects.
- **Error contracts** – Both orchestrators should treat missing or stale pointers as fatal (surface `::error:: Handshake <stamp> not available`). This keeps CI runs honest: Ubuntu cannot declare success unless it records the pointer, and Windows cannot finish unless it pushes the publish metadata.
- **Versioning** – Store a `schema` field in every pointer (`handshake/v1`), so new metadata can be added without breaking older consumers. Version bumps become intentional PRs that modify both pipelines simultaneously.
- **Watchdog workflow** – `.github/workflows/handshake-watchdog.yml` runs hourly (or on demand), downloads the freshest `handshake-pointer-*` artifact via the Actions API, and feeds it to `scripts/handshake_watchdog.py`. When a payload sits in `ubuntu-ready` longer than the configured TTL (default 90 min, override via workflow dispatch inputs or repo vars such as `HANDSHAKE_WATCHDOG_TTL`/`HANDSHAKE_WATCHDOG_LABEL`/`HANDSHAKE_WATCHDOG_NOTIFY`), the watchdog comments on/opens the “Local CI handshake watchdog” issue so operators know a lease expired (and optionally pings custom handles). Once a Windows run replies, the watchdog closes the issue again, giving us an auditable heartbeat for the control plane.

By promoting the rendezvous into GitHub artifacts/issues, we remove the “local box must be waiting” assumption and gain an auditable log of who imported which payload. The local runner still writes under `out/`, but its control flow is driven by GitHub metadata that any machine (or human) can inspect.

Windows signing stage (40) environment overrides:
- `LOCALCI_SIGN_TS_URL` – RFC‑3161 timestamp server URL (default Digicert). Propagated to the signing harness.
- `LOCALCI_SIGN_TIMEOUT` – per‑file timestamp timeout in seconds (overrides profile value).
- `LOCALCI_SIGN_SKIP_PREFLIGHT` – set to `true` to skip the timestamp‑server connectivity preflight.
- `LOCALCI_SIGN_PREFLIGHT_STRICT` – set to `true` to fail the stage if the preflight cannot reach the server (otherwise only warns).
- `LOCALCI_SIGN_PREFLIGHT_MODE` – shorthand (`warn`, `strict`, `skip`) for the preflight behavior.

Windows LabVIEW/VIPM stages honor the following profile settings (see `local-ci/windows/profile.psd1`):
- `LabVIEWVersion` / `LabVIEWBitness` feed the analyzer stage.
- `EnableDevModeStage`, `DevModeAction`, `DevModeVersions`, `DevModeBitness`, `DevModeOperation`, `DevModeIconEditorRoot`, `DevModeDisableAtEnd`, `DevModeAllowForceClose`, `AutoVendorIconEditor`, `IconEditorVendorUrl`, `IconEditorVendorRef` control stage 25 (auto-vendor + enable dev-mode tokens before analyzer/LUnit flows and optionally mark them for cleanup). When `DevModeDisableAtEnd` is `$true`, any attempt to set `DevModeAction` to `Disable` is ignored with a warning so dev mode stays active until Stage 55 runs. Stage 25 also exports `LOCALCI_DEV_MODE_LOGROOT` so rogue-LabVIEW detection logs land under the current run directory. Set `DevModeAllowForceClose` (or `LOCALCI_DEV_MODE_FORCE_CLOSE=1`) only when you explicitly want Stage 25 to fall back to force-killing LabVIEW/LVCompare processes after g-cli shutdown attempts fail.
- `EnableValidationStage`, `ValidationScriptPath`, `ValidationConfigPath`, `ValidationResultsPath`, `ValidationTestSuite`, `ValidationRequireCompareReport`, and `ValidationAdditionalArgs` configure stage 35.
- `EnableMipLunitStage`, `MipLunitScriptPath`, `MipLunitResultsPath`, `MipLunitAnalyzerConfig`, `MipLunitAdditionalArgs` control stage 36.
- `EnableVipmStage`, `VipmVipcPath`, `VipmRelativePath`, `VipmDisplayOnly` control stage 45 (and can be overridden per run via `LOCALCI_VIPM_VIPC`).
- `PreserveRunOnFailure`, `ArchiveFailedRuns`, and `FailedRunArchiveRoot` control whether failed runs stay on disk (and optionally get copied under `out/local-ci/archive/`). You can override per invocation using `LOCALCI_PRESERVE_RUN=0|1` and `LOCALCI_ARCHIVE_RUN=0|1`.

When `AutoVendorIconEditor` is true and `IconEditorVendorUrl` is omitted, Stage 25 derives `https://github.com/<owner>/labview-icon-editor.git` from the current repo’s `origin` owner (falling back to `git config user.name` with whitespace removed) and defaults `IconEditorVendorRef` to `develop`, so each developer automatically syncs their fork before toggling dev mode.

## Logging & Observability
- Use `Start-Transcript` / `tee` per stage.
- Emit a consolidated Markdown summary `out/local-ci/<stamp>/SUMMARY.md` with:
  - Stage status table.
  - Key metrics (tests run, scripts signed, timestamps).
  - Paths to artifacts and transcripts.
- Provide helper `tools/Collect-LocalCIReport.ps1` that zips the run directory for upload/attach to PR comments.

## Parity Checklist vs Actions
| Concern | Windows Local CI | GitHub Actions |
| --- | --- | --- |
| Build outputs go to `out/` | ✅ Stage 20 enforces | ✅ Build job uses `SIGN_ROOT=out` now |
| Script signing behavior | ✅ Stage 40 wraps `scripts/Test-Signing.ps1` (fork + trusted) | ✅ `ci-windows-signed` |
| Pester tag coverage | ✅ Configurable tags, default all relevant suites | ✅ `ci-ubuntu-minimal` focuses on smoke |
| Artifact hashing | ✅ Stage 50 uses `Hash-Artifacts.ps1` | ✅ Ubuntu workflow already does |
| Secrets/sealed certs | ✅ Test cert generator + env injection | ✅ Environments supply real certs |

## Implementation Plan (incremental)
1. Scaffold `local-ci/windows/Invoke-LocalCI.ps1` with stage loop + config loader.
2. Extract existing logic into stage scripts (`stages/30-Tests.ps1` calls `Invoke-RepoPester`, etc.).
3. Mirror the pattern for Ubuntu shell scripts.
4. Update `docs/testing.md` to link to this design and document the CLI usage.
5. (Optional) Add `gh workflow run local-ci` alias or VSCode task hooking into the runner.

This design keeps local validation ergonomic, matches the hardened CI paths, and creates a clear bridge from “golden box” verification to hosted GitHub Actions. Once implemented, every developer can run `local-ci/windows/Invoke-LocalCI.ps1` (or the Ubuntu variant) before pushing, ensuring identical behavior to the gated workflows.
