# Icon Editor Lab

Tooling, pipelines, and tests that support the Icon Editor lab experience:

- LabVIEW dev-mode, VI Analyzer, and VI compare workflows.
- VIPC/VIPB packaging via vipmcli/g-cli and openvipbcli.
- x-cli orchestration and agent-friendly JSON workflows.

This README is meant to be readable by both humans and GPT-style agents. For detailed tool-by-tool docs, see `src/tools/README.md` and the ADRs under `architecture/adr/`.

---

## Architecture Overview

At a high level, the lab is split into three layers:

1. **Tooling & scripts** (this repo):
   - PowerShell modules and scripts under `src/tools` and `tools/`.
   - x-cli (`tools/x-cli-develop`) as the JSON-driven orchestrator.
   - openvipbcli (`tools/openvipbcli-main`) for VIPB operations.

2. **Providers & external tools**:
   - LabVIEW/LabVIEWCLI/LVCompare (Windows only, not in this repo).
   - vipmcli/g-cli for VIPC/VIP builds (also external).

3. **Agents & CI**:
   - VS Code tasks, GitHub Actions workflows, and Codex helpers that drive the tooling.

```mermaid
flowchart LR
  Dev[Developer / Codex agent] --> Tasks[VS Code tasks / CI jobs]
  Tasks --> PS[PowerShell tools (src/tools, tools/)]
  PS --> XCli[x-cli (JSON workflows)]
  XCli --> Providers[Providers (labviewcli, vipm-gcli, gcli, etc.)]
  Providers --> Ext[External tools on host (LabVIEWCLI, vipmcli/g-cli, LVCompare)]
```

The rule of thumb is:

- **Agents/humans** call high-level scripts or x-cli commands.
- Scripts/x-cli select providers (labviewcli, gcli, vipm-gcli, etc.).
- Providers call the actual binaries (LabVIEWCLI, vipmcli, g-cli) on the host where they are installed.

For Codex/agents, the preferred entry is `tools/codex/Invoke-LabVIEWOperation.ps1`, which maps a simple “operation + JSON request” to the right x-cli workflow.

---

## icon-editor-lab Tooling Image (Ubuntu)

To make x-cli + tooling easy to use on Ubuntu (without installing .NET, PowerShell, etc. every time), ADR-0003 defines an **icon-editor-lab tooling image** built from this repo and published to GHCR.

Conceptually, the image looks like this:

```mermaid
flowchart TB
  subgraph Image[icon-editor-lab tooling image (Ubuntu)]
    dotnet[.NET runtime]
    pwsh[PowerShell 7]
    xcli[x-cli (published from tools/x-cli-develop)]
    openvipbcli[openvipbcli (published from tools/openvipbcli-main)]
    scripts[src/tools/*.ps1, tools/*.ps1]
  end

  Host[Dev machine / CI runner] -->|docker run -v /repo:/work| Image
  Image -->|bind-mounted repo| Workdir[/work (icon-editor-lab workspace)]
```

Key properties:

- Built via `tools/Dockerfile.icon-editor-lab-tooling-ubuntu`:
  - `dotnet publish` for x-cli and openvipbcli **inside the container**.
- Runtime includes:
  - PowerShell 7 (`pwsh`),
  - .NET runtime,
  - shims `x-cli` and `openvipbcli` on `PATH`,
  - and expects a bound repo at `/work`.
- Does **not** contain LabVIEW, LabVIEWCLI, LVCompare, vipmcli, or g-cli—those live on Windows hosts.

Typical usage pattern:

- Local dev / Codex:
  - `docker build -f tools/Dockerfile.icon-editor-lab-tooling-ubuntu -t icon-editor-lab/tooling-ubuntu:local .`
  - `docker run --rm -it -v "$PWD:/work" -w /work icon-editor-lab/tooling-ubuntu:local pwsh`
  - Inside the container:
    - `pwsh tools/codex/Invoke-XCliWorkflow.ps1 -Workflow vi-compare-run -RequestPath configs/vi-compare-run-request.sample.json`
    - or `x-cli vi-compare-run --request configs/vi-compare-run-request.sample.json`

On GitHub Actions, the image is intended to be consumed from GHCR (see ADR-0003), e.g. as a `container:` for Linux jobs that validate x-cli workflows and JSON contracts.

---

## For Agents (GPTs, automation)

When you need to perform LabVIEW-related operations, follow this hierarchy:

1. **Prefer x-cli + Codex helpers**:
   - Use `tools/codex/Invoke-LabVIEWOperation.ps1` with an operation name and JSON request.
   - That helper calls `tools/codex/Invoke-XCliWorkflow.ps1`, which runs x-cli with the right workflow.

2. **Never call binaries directly**:
   - Do not invoke `LabVIEW.exe`, `LabVIEWCLI.exe`, `g-cli.exe`, or VIPM GUIs directly.
   - Use the providers (`LabVIEWCli.psm1`, `GCli.psm1`, `VipmDependencyHelpers.psm1`, etc.) or x-cli.

3. **Respect guardrails**:
   - Pre-push checks (`src/tools/PrePush-Checks.ps1`) enforce that new scripts do not call `LabVIEW.exe` or `VIPM.exe` directly.
   - `Verify-LVCompareSetup.ps1 -ProbeCli` and `Warmup-LabVIEWRuntime.ps1` now have guards that point back to `tools/codex/Invoke-LabVIEWOperation.ps1` instead of probing `LabVIEWCLI.exe` or launching `LabVIEW.exe` directly.

For a deeper tool-level playbook (including exact commands and env vars), see:

- `src/tools/README.md` (x-cli workflow table, validation gates, pre-push checks).
- `architecture/adr/ADR-0002-xcli-staged-publish-and-vi-compare.md`.
- `architecture/adr/ADR-0003-xcli-tooling-image-and-openvipbcli.md`.

### Example: CI job using the tooling image

The following GitHub Actions job shows how to use the icon-editor-lab tooling image from GHCR to run the agent validation plan on Ubuntu:

```yaml
jobs:
  agent-validation:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/<org>/icon-editor-lab/tooling-ubuntu:latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Run agent validation plan
        working-directory: /github/workspace
        run: |
          pwsh -NoLogo -NoProfile -File tools/validation/Invoke-AgentValidation.ps1 `
            -PlanPath configs/validation/agent-validation-plan.json
```

Agents (and humans) can adapt this pattern for other workflows by changing the script/plan path or by invoking `tools/codex/Invoke-LabVIEWOperation.ps1` or `x-cli` directly inside the same container.

---

## Release Workflow

1. Ensure the latest `develop` commit is green (CI + coverage gates >= 75%).
2. Tag the commit with the next semantic version (for example: `git tag v0.2.0 && git push origin v0.2.0`).
3. The `release.yml` workflow runs automatically for `v*` tags or via `workflow_dispatch`, executes the Pester suite, enforces the coverage floors, uploads test/coverage artifacts, and creates the GitHub Release with those artifacts attached.

---

## Local Git Hooks (optional)

- Pre-commit path policy guard: `tools/git-hooks/Invoke-PreCommitChecks.ps1` scans staged PowerShell files for hard-coded drive-letter paths and fails the commit if found.
- Pre-push test gate: `tools/git-hooks/Invoke-PrePushChecks.ps1` runs `Invoke-Pester -Path tests -CI` and writes NUnit XML under `artifacts/test-results`.
- One-liner setup: `pwsh -NoLogo -NoProfile -File tools/git-hooks/Install-GitHooks.ps1` (creates `.git/hooks/pre-commit` and `.git/hooks/pre-push` that invoke the scripts above).
- To temporarily skip locally, set `ICONEDITORLAB_SKIP_PRECOMMIT=1` or `ICONEDITORLAB_SKIP_PREPUSH=1`.
