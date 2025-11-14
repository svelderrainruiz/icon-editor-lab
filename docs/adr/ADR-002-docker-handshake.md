# ADR-002: Dockerized Local CI Handshake Tooling

## Status
Accepted (2025-11-14)

## Context
- Ubuntu stages currently run directly on GitHub-hosted Ubuntu runners, installing Node/PowerShell/actionlint/etc. ad hoc in each job.
- We need a reproducible environment to run linting, coverage, and tooling intent checks locally (outside GitHub) and ensure Gatekeeper runs (Stage 25) have deterministic dependencies.
- Developers want the ability to sanity-check test/provider coverage without pushing to GitHub, while Windows consumer jobs still run on the same Windows machine hosting Docker Desktop.

## Decision
1. **Base tools image**
   - Build a runtime-only Docker image (`icon-editor-lab/tools:local-ci`) from `mcr.microsoft.com/dotnet/runtime:8.0` that installs Node 20, Python + ruamel, PowerShell 7, GH CLI, markdownlint, actionlint, and the repo’s validation scripts.
   - Package metadata files (`tests/Pester.runsettings.psd1`, `local-ci/ubuntu/config.yaml`, `tools/local-ci/Test-ToolingIntent.ps1`) into `/opt/local-ci/`.
   - Stage 25 in the Ubuntu pipeline builds this image, validates CLI availability, and runs `/opt/local-ci/Test-ToolingIntent.ps1` to verify tests/providers/config intent.

2. **Optional Ubuntu runner**
   - Derive a second image (`icon-editor-lab/ubuntu-runner`) from the base tools image.
   - Include the repo’s `local-ci/ubuntu` scripts plus helper PowerShell utilities (`Test-ToolingIntent.ps1`, `Schedule-ViStage.ps1`) and a wrapper `/usr/local/bin/localci-run-handshake` that:
     1. Expects the repository bind-mounted at `/work` and artifacts emitted under `/work/out`.
     2. Accepts flags identical to `local-ci/ubuntu/invoke-local-ci.sh` (e.g., `--skip`/`--only`).
     3. Runs the Ubuntu stages inside the container while emitting logs/artifacts to the mounted workspace.
   - Document VS Code tasks / docker commands for both full runs (`localci-run-handshake --skip …`) and targeted helpers (e.g., `pwsh -File /opt/local-ci/Schedule-ViStage.ps1 -Stamp <stamp>`), enabling developers to execute the Ubuntu pipeline or VI rendering locally without GitHub.

3. **Windows consumer**
   - Continue running the Windows consumer natively on the same Windows host that manages Docker Desktop. No Windows container is required; the host downloads `out/local-ci-ubuntu/<stamp>` and runs LabVIEW/TestStand automation as before.

## Consequences
- Ubuntu stages get a deterministic tooling layer; Stage 25 fails early if tests/providers drift or dependencies are missing.
- Developers can run `docker run --rm -v "$PWD:/work" icon-editor-lab/tools:local-ci pwsh -File /opt/local-ci/Test-ToolingIntent.ps1 -RepoRoot /work` to validate intent without GitHub.
- Future expansion (Ubuntu runner image) is straightforward without changing the Windows consumer architecture.
- Secrets and artifact publishing remain in GitHub Actions; the image stays stateless, relying on mounted workspaces.
