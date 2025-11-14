# Dockerized Local CI Handshake Design (Ubuntu → Windows helper)

## Goals
1. Keep the existing two-stage workflow (Ubuntu builds first, Windows consumer follows) but provide a reproducible Docker image for the Ubuntu stages.
2. Allow developers to run the entire Ubuntu handshake locally via `docker run` without waiting on GitHub.
3. Reuse the same Windows machine (already hosting Docker Desktop) as the Windows consumer. No additional Windows containers required.

## Images
- **Base tools image (`icon-editor-lab/tools:local-ci`)**
  - Inherits from `mcr.microsoft.com/dotnet/runtime:8.0`.
  - Installs Node 20, Python + ruamel, PowerShell 7, GitHub CLI, markdownlint, actionlint, pwsh modules (Pester, powershell-yaml).
  - Copies repo metadata (`tests/Pester.runsettings.psd1`, `local-ci/ubuntu/config.yaml`, `tools/local-ci/Test-ToolingIntent.ps1`).
  - Entry points:
    - `bash` / `pwsh` (default) for ad-hoc tasks.
    - `/opt/local-ci/Test-ToolingIntent.ps1` used by CI to validate test/provider coverage intent.
- **Optional derived "Ubuntu runner" image** (future)
  - Extends the base image and adds a wrapper script `localci-run-handshake` that calls `local-ci/ubuntu/invoke-local-ci.sh` with appropriate mounts. Developers could bind-mount their workspace at `/work` and run the entire Ubuntu pipeline locally. Tag: `icon-editor-lab/ubuntu-runner:local-ci`.

## Workflow Integration
- GitHub workflow still performs `actions/checkout`, artifact uploads, and pointer updates.
- Stage 25 builds the base image, validates CLI availability, then runs `Test-ToolingIntent.ps1` inside the container to ensure test/provider metadata is intact.
- Coverage, VI compare, packaging, and manifest generation remain on the Ubuntu runner (outside the container). They rely on the same scripts but can optionally call into the container for deterministic tooling.

## Local Developer Experience
- Developers with Docker Desktop can run `docker run --rm -v "$PWD:/work" icon-editor-lab/tools:local-ci pwsh -File /opt/local-ci/Test-ToolingIntent.ps1 -RepoRoot /work` to sanity-check tests/providers before pushing.
- Optionally, add a VS Code task (`Local CI: Ubuntu (docker)`) that invokes the future `localci-run-handshake` entry point for full local runs.

## Windows Consumer
- No containerization; the same Windows machine that hosts Docker Desktop continues running the Windows consumer job natively. It downloads the Ubuntu artifact, restores it into `out/local-ci-ubuntu/<stamp>`, and runs LabVIEW/TestStand automation.
- Windows watcher scripts remain unchanged; they only need the artifact produced by the Ubuntu stage (which may have been generated via containerized tools).

## Considerations
- Secrets (GHCR, artifact PATs) stay in GitHub Actions; containers are stateless and rely on mounted workspace.
- Artifact paths and pointer logic remain file-based so Windows consumers can operate on the same `out/local-ci-ubuntu/<stamp>` directories.
- Splitting images is optional; starting with a single base tools image keeps maintenance lower and still enables local Docker-based validation.
