# LabVIEW Agent Validation Plan

**Purpose:** Provide a repeatable test matrix for Codex agents (and new contributors) to validate x-cli workflows, vipmcli integration, and publish tasks. Each scenario references the helper `tools/codex/Invoke-LabVIEWOperation.ps1` so future agents can iterate without rediscovering the command surface.

## Environment / Prerequisites
- Windows runner with:
  - LabVIEW 2021 (PPL builds), LabVIEW 2023 (vipmcli packaging), LabVIEW 2025 x64 (VI compare reports).
  - LabVIEWCLI/LVCompare paths in `PATH`.
  - vipmcli/g-cli installed and signed in.
- Repository variables / env:
  - `XCLI_ALLOW_PROCESS_START=1`
  - `XCLI_REPO_ROOT=<repo root>`
  - `XCLI_LABVIEW_INI_PATH=<LabVIEW install>\LabVIEW.ini`
  - `XCLI_LOCALHOST_REQUIRED_PATH=<repo root>`
  - `XCLI_STAGE_CHANNEL`, `XCLI_QA_DESTINATION`, `XCLI_UPLOAD_MODE` (for publish tests).
- `.github/actions/apply-vipc/ApplyVIPC.ps1` stub remains until the real action is vendored. Expect the “vipmcli apply” smoke to stop at the stub unless the real script is present.

## Test Matrix

| ID | Scenario | Command | Inputs | Expected output |
| --- | --- | --- | --- | --- |
| VC-01 | VI compare replay (sample scenario) | `pwsh tools/codex/Invoke-LabVIEWOperation.ps1 -Operation vi-compare -RequestPath configs/vi-compare-run-request.sample.json` | Sample request referencing `scenarios/sample/vi-diff-requests.json`, dry-run modes toggled via JSON | `.tmp-tests/vi-compare-replays/<name>/vi-comparison-summary.json` includes suppression metadata, bundle zip produced if `skipBundle=false`. |
| VC-02 | VI compare real replay (vi-attr) | Same command but request pointing to `scenarios/vi-attr/vi-diff-requests.json`, `dryRun=false`, suppression flags toggled | Real LabVIEW execution (if LabVIEW 2025 available). Summary `counts.compared > 0`. Failure if LocalHost.LibraryPaths missing (ensures guard works). |
| VC-03 | VI compare verify | `dotnet run --project tools/x-cli-develop/src/XCli/XCli.csproj -- vi-compare-verify --summary .tmp-tests/vi-compare-replays/<name>/vi-comparison-summary.json` | Uses summary from VC-01/02 | CLI confirms each suppression flag matches. Expect exit 0. |
| VA-01 | VI Analyzer run | `pwsh tools/codex/Invoke-LabVIEWOperation.ps1 -Operation vi-analyzer -RequestPath configs/vi-analyzer-request.sample.json` | Config referencing `src/configs/vi-analyzer/missing-in-project.viancfg`, `dryRun=true` or staging output root under `.tmp-tests/vi-analyzer/...` | `vi-analyzer.json` with schema `icon-editor/vi-analyzer@v1`. On missing CLI path, expect “LabVIEWCLI.exe not found” error (NC- requirement). |
| VA-02 | VI Analyzer verify (CLI probe) | `dotnet run --project tools/x-cli-develop/src/XCli/XCli.csproj -- vi-analyzer-verify --labview-path "C:\Program Files\National Instruments\LabVIEW 2023\LabVIEW.exe"` | Real path or intentionally invalid path | Exit 0 when CLI present; exit 1 with remediation message otherwise. |
| VIPA-01 | vipmcli dependency apply (prepare-only) | `pwsh tools/codex/Invoke-LabVIEWOperation.ps1 -Operation vipm-apply -RequestPath configs/vipm-apply-request.sample.json` | Set `"toolchain": "g-cli"`, `"skipExecution": true` in request to avoid real apply on dev boxes | Should reach `.github/actions/apply-vipc/ApplyVIPC.ps1` stub and fail with “real automation not present.” Confirms wrapper wiring. |
| VIPA-02 | vipmcli dependency apply (execute) | Same as above but `skipExecution` false and real ApplyVIPC script available | Should log Replay details and run `.github/actions/apply-vipc/ApplyVIPC.ps1` (real script). Watch for g-cli invocation, `.vipc` apply logs. |
| VIPB-01 | vipmcli package replay (prepare only) | `pwsh tools/codex/Invoke-LabVIEWOperation.ps1 -Operation vipm-build -RequestPath configs/vipm-build-request.sample.json` | Run with `-Execute:$false` via VS Code task to skip heavy build | Console output shows release note generation and command plan. |
| VIPB-02 | vipmcli build (prepare only) | `pwsh tools/codex/Invoke-LabVIEWOperation.ps1 -Operation vipmcli-build -RequestPath configs/vipmcli-build-request.sample.json` | Request referencing vendor snapshot, `skipBuild` true. | Validates vendor sync + CLI wiring. For full build, set `SkipBuild=false`. |
| PPL-01 | Packed project build | `pwsh tools/codex/Invoke-LabVIEWOperation.ps1 -Operation ppl-build -RequestPath configs/ppl-build-request.sample.json` | Requires `vendor/icon-editor/.github/actions/build-lvlibp/Build_lvlibp.ps1`. Use stub if not available. | Response JSON `icon-editor/ppl-build@v1` listing per-bitness exit codes. |
| SEED-01 | Seed VipbJsonTool sanity | `pwsh tools/validation/Test-SeedVipbRoundTrip.ps1` (invoked automatically by the plan) | No NI prerequisites; builds the bundled seed CLI and performs JSON→VIPB→JSON round-trip. | Confirms the CI/CD seed tooling functions on clean machines (Linux container or Windows host). |
| PUB-01 | Stage/Test pipeline | Run VS Code tasks or `pwsh tools/Stage-XCliArtifact.ps1 …` etc. | Provide `artifacts/xcli-win-x64.zip`. | `stage-info.json` written, `Test-XCliReleaseAsset.ps1` collects vi-compare bundle, `Promote/Upload` copy assets. |

## How to reuse in Codex sessions
1. Decide which scenario you need to test.
2. Copy or adjust the sample request JSON under `configs/`.
3. Run `tools/codex/Invoke-LabVIEWOperation.ps1 -Operation <scenario> -RequestPath <json>`; set env vars as described.
4. Capture outputs (`.tmp-tests/...`, `.tmp-tests/xcli-stage/...`, etc.) and attach summary/bundle paths to your report.

## Automation hooks
- **Plan file:** `configs/validation/agent-validation-plan.json` defines the scenarios (IDs, operations, request files, expected outcomes). Update this JSON when you add new validation coverage.
- **Script:** `tools/validation/Invoke-AgentValidation.ps1 -PlanPath configs/validation/agent-validation-plan.json` runs the entire plan, writes a summary under `.tmp-tests/validation/agent-validation-<stamp>.json`, and fails on unexpected errors. Use the `Release: Validate LabVIEW agent` VS Code task to run it locally.
- **GitHub Actions:** `.github/workflows/agent-validation.yml` invokes the same script on pull requests and pushes targeting `release/*` or `rc/*` branches (self-hosted Windows runner required). Configure the workflow as a required status check before merging release candidates.

Add new scenarios to this matrix (and the JSON plan) as workflows expand. Keep the commands grounded in the helper so future agents only need to edit JSON and run a single script.
