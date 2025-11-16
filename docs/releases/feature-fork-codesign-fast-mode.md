# feature/fork-codesign-fast-mode — PR outline

## What this feature adds
- **Codesign fast mode** – `tools/Invoke-ScriptSigningBatch.ps1` now supports fork sampling via `-MaxFilesPerBatch`/`-SamplingMode` plus optional metrics emission. `.github/workflows/ci-windows-signed.yml` feeds `FORK_SIGN_SAMPLE=150` so forks only sign a predictable slice while trusted runs still timestamp everything.
- **x-cli integration** – vendored `tools/x-cli-develop` (`XCli.sln`, `scripts/*.ps1`, `tests/*`) is consumed as a simulation provider from `src/tools/icon-editor/IconEditorDevMode.psm1` and the handshake utilities (`tests/tools/Run-HandshakeSim.ps1`, `tests/tools/Summarize-Handshakes.ps1`). The subtree stays isolated as a vendor drop; our CI uses its command-line surface but never gates on its coverage.
- **Artifact + diagnostics tooling** – `tools/Get-GitHubRunArtifacts.ps1` fetches run artifacts via `gh` or REST, and `tests/tools/Summarize-Handshakes.ps1` materializes end-to-end handshake health into `tests/results/_agent/icon-editor/handshake-summary.json` so LvAddon agents can reason about parity issues faster.

## How to invoke it
1. **Fork codesign sampling** (mirrors CI fast mode):  
   ```pwsh
   pwsh -NoLogo -NoProfile -File tools/Invoke-ScriptSigningBatch.ps1 `
     -Root unsigned `
     -CertificateThumbprint <thumbprint> `
     -MaxFiles 500 `
     -MaxFilesPerBatch 150 `
     -SamplingMode First `
     -Mode fork `
     -SkipAlreadySigned `
     -EmitMetrics `
     -SummaryPath $env:GITHUB_STEP_SUMMARY
   ```
2. **Handshake/x-cli replay** (non-destructive): `pwsh tests/tools/Run-HandshakeSim.ps1 -Scenario ok -UbuntuManifestPath out/local-ci-ubuntu/<run>/ubuntu-run.json` seeds `tools/x-cli-develop` to mimic GitHub handshake states without touching real assets.
3. **LvAddon dev-mode sims**: `pwsh tests/tools/Collect-LvAddonLearningData.ps1 -Actions Both -Scenarios timeout,rogue -MaxRecords 20` drives `XCliSim` via `tests/tools/Run-DevMode-Debug.ps1` and refreshes learning snippets under `tests/results/_agent/icon-editor/`.

## CI coverage status
- `.github/workflows/coverage.yml` still enforces the global ≥75 % line-rate gate plus per-file floors for `src/Core.psm1` and `tools/Build.ps1` only when those files exist. Uploads for Cobertura + JUnit artifacts remain wrapped in `if: always()`.
- docs link checking (`.github/workflows/docs-link-check.yml`) is unmodified—`lycheeverse/lychee-action@v1` still runs on the ubuntu-latest matrix and uploads `.lychee` under `if: always()`.
- x-cli content (C# + Python + PS under `tools/x-cli-develop/`) is treated as vendor tooling: it is not part of the curated test set nor the coverage gate. Integration confidence now comes from lightweight Pester tests (`tests/Scripts/IconEditorDevModeXCli.Tests.ps1`) that mock `dotnet` and assert argument construction + failure handling without taking a dependency on the subtree itself.
- Latest handshake import (`tests/results/_agent/icon-editor/handshake-summary.json`) shows Ubuntu coverage at 100 % vs the 75 % floor, with per-stage diagnostics persisted for traceability.

## Diagnostics + readiness checklist
- ✅ New summary artifacts: `tests/results/_agent/icon-editor/handshake-summary.json` (handshake parity), `tests/results/_agent/icon-editor/xcli-learning-snippet.json` (now links back to handshake summary), and `tests/results/_agent/icon-editor/xcli-devmode-summary.json` all consume the same vendor telemetry folder (`tools/x-cli-develop/temp_telemetry`).  
- ✅ Script-level guards: `IconEditorDevMode.psm1` throws when `tools/x-cli-develop/src/XCli/XCli.csproj` is missing, and the new tests validate both that guard and the safe fallback when `dotnet run --project` fails.  
- ✅ Fork sampling metrics: `Invoke-ScriptSigningBatch` emits JSON metrics into the runner summary so we can audit how many files were sampled, skipped, or timed-out during CI.  
- ✅ Artifact fetch helper: `tools/Get-GitHubRunArtifacts.ps1` prefers `gh run download`, auto-discovers artifact names, and falls back to REST with `Invoke-WebRequest` when the CLI/token is unavailable.

## Risks & mitigations
1. **Large vendor subtree (`tools/x-cli-develop`)** – treat as a pinned dependency. None of the new CI gates traverse it; we only depend on its CLI surface (`dotnet run --project tools/x-cli-develop/src/XCli/XCli.csproj`). Pester tests mock that hop so PRs do not need the actual vendor payload to pass.
2. **Fork-mode signing samples less content** – controlled via `FORK_SIGN_SAMPLE`/`FORK_SIGN_SAMPLING_MODE`. Trusted builds still force timestamping on the entire `unsigned` tree, and metrics plus `MAX_SIGN_FILES` warnings make under-sampling visible.
3. **Handshake summarizer relies on local artifacts** – scripts bail out with warnings (not errors) when `handshake/pointer.json` or `out/local-ci/*` are absent, keeping the suite non-destructive. Agents can regenerate summaries by rerunning `tests/tools/Run-LvAddonLearningLoop.ps1` after a handshake capture.
4. **Artifact download helper writes under repo root** – `tools/Get-GitHubRunArtifacts.ps1` defaults to `logs-artifacts/` beneath `WORKSPACE_ROOT`; callers can override `-DestinationRoot` to sandbox writes when running outside CI.
