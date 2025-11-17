# ADR-0003: icon-editor-lab Tooling Image (Ubuntu)

Status: Proposed  
Date: 2025-11-17  
Decision Owners: Build Lead, Agents Lead

## Context

The icon-editor-lab repository now exposes a rich command surface via x-cli (`tools/x-cli-develop`) and wraps LabVIEW-adjacent workflows (vi-compare, vi-analyzer, vipmcli/g-cli, PPL build) behind JSON-driven commands. There is also a separate .NET utility (`tools/openvipbcli-main`) that provides an open-source command-line interface for VIPB build operations.

Today:

- x-cli and openvipbcli are built ad hoc on developer machines or CI runners.
- Ubuntu workflows (`ci-ubuntu-minimal`, local devcontainers) need a consistent way to:
  - Run x-cli workflows in emulated mode (no NI toolchains).
  - Exercise JSON contracts and providers without installing .NET/Node/Pwsh on every run.
  - Call openvipbcli for VIPB-related automation.
- Codex agents are expected to call x-cli via `tools/codex/Invoke-XCliWorkflow.ps1` / `Invoke-LabVIEWOperation.ps1`, but there is no pre-built container image that:
  - Contains x-cli and openvipbcli binaries.
  - Sets up a predictable environment (`pwsh`, dotnet runtime, basic CLI tooling).

We want a reproducible, shareable tooling image that can be used by:

- Local developers (Docker, VS Code devcontainers).
- GitHub Actions (Linux jobs).
- Codex agents (by referencing the same image in CI or local Docker).

This image must:

- Build x-cli and openvipbcli *inside* the container from the repo source.
- Not contain LabVIEW, LabVIEWCLI, LVCompare, or vipmcli; those remain on Windows hosts.
- Be published to GitHub Container Registry (GHCR) for reuse.

## Decision

We will introduce a dedicated Ubuntu-based **icon-editor-lab tooling image** that:

- Builds and ships the lab’s .NET tooling from this repo (notably x-cli and openvipbcli).
- Exposes those tools as first-class CLIs (`x-cli`, `openvipbcli`) inside the container.
- Includes PowerShell 7 and minimal supporting tools (git, curl, etc.) so the broader `src/tools` PowerShell scripts can run.
- Is published to GHCR and referenced by VS Code tasks / devcontainers and CI as the canonical way to run icon-editor-lab tooling on Ubuntu.

The key elements are:

1. **Dockerfile (`tools/Dockerfile.icon-editor-lab-tooling-ubuntu`)**

   - Multi-stage build:
     - Stage `build`:
       - Base: `mcr.microsoft.com/dotnet/sdk:<pinned-version>`.
       - `WORKDIR /src`.
       - `COPY . .` (icon-editor-lab repo contents).
       - `dotnet publish tools/x-cli-develop/src/XCli/XCli.csproj -c Release -o /out/xcli`.
       - `dotnet publish tools/openvipbcli-main/<csproj> -c Release -o /out/openvipbcli`.
     - Stage `runtime`:
       - Base: `mcr.microsoft.com/dotnet/runtime:<matching-version>` (or `aspnet` if needed).
       - Install PowerShell 7 (`pwsh`), git, curl, unzip.
       - `COPY --from=build /out/xcli /opt/xcli`.
       - `COPY --from=build /out/openvipbcli /opt/openvipbcli`.
       - Add shims to `/usr/local/bin`:
         - `x-cli` → runs `dotnet /opt/xcli/XCli.dll "$@"` (or the platform-specific binary if we use `-r` publish).
         - `openvipbcli` → runs `dotnet /opt/openvipbcli/OpenVipbCli.dll "$@"`.
       - Set defaults:
         - `ENV XCLI_ALLOW_PROCESS_START=1`.
         - Do *not* bake `XCLI_REPO_ROOT`; callers typically bind-mount their workspace to `/work` and set this themselves.
       - `WORKDIR /work` as the convention for bind-mounted repos.

2. **GitHub Actions workflow (`.github/workflows/icon-editor-lab-tooling-image.yml`)**

   - Triggers:
     - `push` to `main`.
     - Tag pushes matching `v*` (for versioned image tags).
   - Steps:
     - Checkout the repo.
     - Login to GHCR with the GitHub-provided token.
     - Build the image with:
       - `docker build -f tools/Dockerfile.icon-editor-lab-tooling-ubuntu -t ghcr.io/<org>/icon-editor-lab/tooling-ubuntu:sha-<shortsha> .`
       - Tag `:latest` on `main`.
       - Tag `:<semver>` on release tags.
     - Push all relevant tags to GHCR.

3. **Developer ergonomics (VS Code & devcontainers)**

   - Add VS Code tasks:
     - `Tools: Build icon-editor-lab tooling image (Ubuntu)` → runs `docker build` against `tools/Dockerfile.icon-editor-lab-tooling-ubuntu` and tags `icon-editor-lab/tooling-ubuntu:local`.
     - `Tools: Shell in tooling image` → runs:
       - `docker run --rm -it -v ${workspaceFolder}:/work -w /work icon-editor-lab/tooling-ubuntu:local pwsh`.
   - Optional devcontainer:
     - `.devcontainer/devcontainer.json` pointing at `ghcr.io/<org>/icon-editor-lab/tooling-ubuntu:latest` with `"workspaceFolder": "/work"` and a bind mount.

4. **Usage pattern and scope**

   - The image is explicitly **tooling-only**:
     - It does not contain LabVIEW, LabVIEWCLI, LVCompare, vipmcli, or g-cli.
     - x-cli workflows that require real LabVIEW continue to run on Windows hosts with LabVIEW installed and providers wired to LabVIEWCLI/g-cli.
   - Supported operations inside the image:
     - x-cli workflows with emulated providers (e.g., vi-compare-run in dry/record mode).
     - VIPB operations via openvipbcli (as long as they do not require LabVIEW).
     - Validation suites such as:
       - `Invoke-Pester tests/Codex.XCli.Tests.ps1`.
       - `tools/validation/Invoke-AgentValidation.ps1` in emulated mode.

## Consequences

**Positive:**

- **Reproducible tooling environment**  
  Any developer or CI job that uses the GHCR image gets the same versions of x-cli, openvipbcli, PowerShell, and the dotnet runtime.

- **Faster iteration for Codex and CI**  
  Building x-cli and openvipbcli inside the image removes per-job build overhead for workflows that only need the CLIs and emulated providers.

- **Clear separation of responsibilities**  
  The tooling image owns:
    - x-cli, openvipbcli, and orchestration scripts.  
  Windows LabVIEW hosts own:
    - LabVIEW, LabVIEWCLI, LVCompare, vipmcli/g-cli, and real-tool execution.

- **Better agent ergonomics**  
  Codex and future agents can:
    - Assume `x-cli` is available in the container.
    - Use `tools/codex/Invoke-XCliWorkflow.ps1` and `Invoke-LabVIEWOperation.ps1` without worrying about dotnet install steps.

**Negative / risks:**

- **Image maintenance overhead**  
  The Dockerfile must be kept in sync with:
    - x-cli project path and target frameworks.
    - openvipbcli project path and target frameworks.
  Changes in these projects require Dockerfile updates and potentially new base images.

- **Versioning complexity**  
  We need a clear tagging strategy (e.g., `latest`, `sha-<shortsha>`, `<semver>`) and documentation so downstream consumers know which image to target.

- **Limited to emulated workflows on Ubuntu**  
  Some contributors might expect the image to “run LabVIEW.” The ADR must clearly state that this is a **tooling** image, not a full LabVIEW runtime environment.

## Implementation Notes

- Align this ADR with ADR-0002 (x-cli staged publish) by:
  - Referencing the same x-cli workflows and JSON contracts.
  - Documenting in `src/tools/README.md` how to invoke x-cli and openvipbcli from inside the tooling image.
- When implementing the Dockerfile:
  - Pin dotnet SDK/runtime versions explicitly.
  - Consider using `dotnet publish` with `-r linux-x64` and `--self-contained false` for predictable runtime behavior.
- When wiring GitHub Actions:
  - Use the `GITHUB_TOKEN` for GHCR auth.
  - Keep the workflow minimal and focused on building/publishing this one image.
