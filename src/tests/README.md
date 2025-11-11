# Tests Overview

The `tests/` folder contains the Pester suites and helper harnesses that guard each Icon Editor workflow (dev mode, Missing In Project, packaging, compare/VI Analyzer, and VIPM scenarios). The suites are primarily invoked through `Invoke-PesterTests.ps1`, but can also be targeted via `-TestsPath` or `-Tag` filters when iterating locally.

## Running the suites

```powershell
# Run everything (default tags/matrix)
pwsh -File Invoke-PesterTests.ps1

# Filter to a single file or tag (e.g., dev mode enable/disable)
pwsh -File Invoke-PesterTests.ps1 -TestsPath tests/Enable-Disable-DevMode.Tests.ps1
pwsh -File Invoke-PesterTests.ps1 -Tag DevMode

# Run helper tests that live under tests/tools
pwsh -File Invoke-PesterTests.ps1 -TestsPath tests/tools/Tools.Help.Tests.ps1
```

All suites assume PowerShell 7+, and most of them import the corresponding module from `tools/` before executing. Self-hosted agents should ensure LabVIEW/LVCompare paths are configured (see `tools/Verify-LVCompareSetup.ps1`) before running anything that interacts with LabVIEW. Detailed per-suite notes live under [`tests/_docs`](./_docs); the tables below link directly to those write-ups.

## Directory structure

| Path | Purpose |
| --- | --- |
| `tests/*.Tests.ps1` | Primary Pester suites grouped by scenario (dev-mode, Missing In Project, packaging, VIPM, compare, etc.). |
| `tests/tools/*.Tests.ps1` | Meta-tests that verify our help/WhatIf/ShouldProcess scaffolding for automation tools. |
| `tests/results/` | Default output root for Pester artifacts (`pester-results.xml`, `_agent/*`, compare reports, etc.). |

## Suite catalog

### Dev-mode enablement & telemetry

| Suite | Validates | Notes / Key scripts |
| --- | --- | --- |
| [Enable-Disable-DevMode.Tests.ps1](./_docs/Enable-Disable-DevMode.Tests.ps1.md) | CLI helpers (`tools/icon-editor/Enable-DevMode.ps1`, `Disable-DevMode.ps1`) toggle state, respect env overrides, and emit policy markers correctly. | Exercises wait/skip env vars and stub CLI paths. |
| [IconEditorDevMode.Tests.ps1](./_docs/IconEditorDevMode.Tests.ps1.md) | Core module API (`IconEditorDevMode.psm1`) for reading/writing/reconciling state. | Covers `Get/Set-IconEditorDevModeState`, policy persistence, and guard env vars. |
| [IconEditorDevMode.Integration.Tests.ps1](./_docs/IconEditorDevMode.Integration.Tests.ps1.md) | End-to-end enable/disable flows with actual policy files and rogue-LV detection toggles. | Imports the module and spawns fixture directories under `TestDrive:`. |
| [IconEditorDevMode.Stability.Tests.ps1](./_docs/IconEditorDevMode.Stability.Tests.ps1.md) | Stress tests the stability harness (open/close LabVIEW loops, sentinel waiters). | Verifies state machine transitions used by `Test-DevModeStability.ps1`. |
| [IconEditorDevMode.Telemetry.Tests.ps1](./_docs/IconEditorDevMode.Telemetry.Tests.ps1.md) | Ensures telemetry emission (JSON attachments, summary text) reflects enable/disable actions. | Parses `_agent/icon-editor/dev-mode-run/…` output. |

### Missing In Project (MIP) scenarios

| Suite | Validates | Notes / Key scripts |
| --- | --- | --- |
| [IconEditorMissingInProject.CompareOnly.Tests.ps1](./_docs/IconEditorMissingInProject.CompareOnly.Tests.ps1.md) | Compare-only path for Missing In Project CLI, ensuring reports render without dev-mode toggles. | Exercises `tools/Invoke-MissingInProjectCLI.ps1` in compare-only mode. |
| [IconEditorMissingInProject.DevMode.Tests.ps1](./_docs/IconEditorMissingInProject.DevMode.Tests.ps1.md) | Dev-mode path (policy toggles, rogue detection) for MIP. | Ensures state clean-up and telemetry guard rails. |
| [Invoke-MissingInProjectCLI.Tests.ps1](./_docs/Invoke-MissingInProjectCLI.Tests.ps1.md) | CLI wrapper input validation and output wiring. | Covers environment fallbacks (MRU slots, compare hints). |
| [Invoke-MissingInProjectSuite.Tests.ps1](./_docs/Invoke-MissingInProjectSuite.Tests.ps1.md) | Full suite orchestration (staging, compare, report writing). | Validates `session-index` artifacts and telemetry attachments. |
| [MipScenarioHelpers.Tests.ps1](./_docs/MipScenarioHelpers.Tests.ps1.md) | Helper functions that build scenario matrices for doc-linked runs. | Guards scenario canonical names and bucket mappings. |

### Packaging, fixtures, and VIPM

| Suite | Validates | Notes / Key scripts |
| --- | --- | --- |
| [IconEditorPackage.Tests.ps1](./_docs/IconEditorPackage.Tests.ps1.md) & [IconEditorPackaging.Smoke.Tests.ps1](./_docs/IconEditorPackaging.Smoke.Tests.ps1.md) | Package manifest inspection, version stamping, and smoke-validation logic. | Works with `tools/icon-editor/Test-IconEditorPackage.ps1` and simulate build outputs. |
| [Simulate-IconEditorBuild.Tests.ps1](./_docs/Simulate-IconEditorBuild.Tests.ps1.md) | Simulation pipeline: extracting fixture VIPs, copying lvlibp artifacts, generating manifests. | Mirrors `tools/icon-editor/Simulate-IconEditorBuild.ps1`. |
| [Stage-IconEditorSnapshot.Tests.ps1](./_docs/Stage-IconEditorSnapshot.Tests.ps1.md) & [Invoke-IconEditorSnapshotFromRepo.Tests.ps1](./_docs/Invoke-IconEditorSnapshotFromRepo.Tests.ps1.md) | Snapshot staging and repo playback flows. | Validate fixture snapshot metadata and `Stage-IconEditorSnapshot.ps1`. |
| [Render-IconEditorFixtureReport.Tests.ps1](./_docs/Render-IconEditorFixtureReport.Tests.ps1.md) / [Update-IconEditorFixtureReport.Tests.ps1](./_docs/Update-IconEditorFixtureReport.Tests.ps1.md) | Fixture reporting and manifest updates. | Ensure JSON schema matches `icon-editor/fixture-manifest@v1`. |
| [Invoke-IconEditorBuild.Tests.ps1](./_docs/Invoke-IconEditorBuild.Tests.ps1.md) / [Invoke-IconEditorVipPackaging.Tests.ps1](./_docs/Invoke-IconEditorVipPackaging.Tests.ps1.md) | Orchestrators for building/installing VIPs. | Guard argument validation and telemetry outputs. |
| [Invoke-FixtureViDiffs.Tests.ps1](./_docs/Invoke-FixtureViDiffs.Tests.ps1.md), [Prepare-FixtureViDiffs.Tests.ps1](./_docs/Prepare-FixtureViDiffs.Tests.ps1.md), [Replay-ApplyVipcJob.Tests.ps1](./_docs/Replay-ApplyVipcJob.Tests.ps1.md), [UpdateVipbDisplayInfo.Tests.ps1](./_docs/UpdateVipbDisplayInfo.Tests.ps1.md) | Fixture diff prep, VIPC replay, and VIPB display metadata updates. | Ensure file staging and diff request generation behave deterministically. |
| [Invoke-VipmDependencies.Tests.ps1](./_docs/Invoke-VipmDependencies.Tests.ps1.md) | VIPM dependency checkout/installation pipeline. | Uses `VendorTools.psm1` resolver helpers. |

### VI Compare / Analyzer / Diff sweeps

| Suite | Validates | Notes / Key scripts |
| --- | --- | --- |
| [Invoke-VIAnalyzer.Tests.ps1](./_docs/Invoke-VIAnalyzer.Tests.ps1.md) | Analyzer CLI wrapper (LabVIEW CLI wiring, result parsing). | Confirms exit codes, timeout flags, and report locations. |
| [Invoke-VIDiffSweep.Tests.ps1](./_docs/Invoke-VIDiffSweep.Tests.ps1.md) & [Invoke-VIDiffSweepStrong.Tests.ps1](./_docs/Invoke-VIDiffSweepStrong.Tests.ps1.md) | Automated VI diff sweeps (normal vs. “strong” noise profiles). | Checks sentinel TTLs, compare report capture, and failure gating. |
| [Render-ViComparisonReport.Tests.ps1](./_docs/Render-ViComparisonReport.Tests.ps1.md) | HTML comparison rendering, noise-profile toggles, and capture JSON wiring. | Guards `tools/Render-ViComparisonReport.ps1`. |
| [Invoke-VIDiffSweepStrong.Tests.ps1](./_docs/Invoke-VIDiffSweepStrong.Tests.ps1.md) | Additional coverage for duplicate-window/sentinel tests. | Ensures CLI-suppressed modes behave. |
| [Invoke-VIDiffSweep.Tests.ps1](./_docs/Invoke-VIDiffSweep.Tests.ps1.md) | Baseline sweep coverage. | Validates noise profile switching and report attachments. |

### VIPM / provider telemetry

| Suite | Validates | Notes / Key scripts |
| --- | --- | --- |
| `Test-ProviderTelemetry.Tests.ps1` | Ensures `tools/Vipm/Test-ProviderTelemetry.ps1` flags failing scenarios and respects `AllowStatuses`. | Feeds synthetic provider-matrix JSON. |
| [Invoke-VipmDependencies.Tests.ps1](./_docs/Invoke-VipmDependencies.Tests.ps1.md) | VIPM dependency orchestrator. | Validates path resolution and summary outputs. |

### Host prep, fixtures, and packaging helpers

| Suite | Validates | Notes / Key scripts |
| --- | --- | --- |
| [Prepare-LabVIEWHost.Tests.ps1](./_docs/Prepare-LabVIEWHost.Tests.ps1.md) | Host prep script (rogue detection, LabVIEW close). | Ensures cleanup commands honor ShouldProcess. |
| [Invoke-IconEditorBuild.Tests.ps1](./_docs/Invoke-IconEditorBuild.Tests.ps1.md) / [Simulate-IconEditorBuild.Tests.ps1](./_docs/Simulate-IconEditorBuild.Tests.ps1.md) | Build + simulate flows. | Guarantee artifact copies and manifest writes. |
| [Render-IconEditorFixtureReport.Tests.ps1](./_docs/Render-IconEditorFixtureReport.Tests.ps1.md) | Fixture report renderer. | Validates JSON contents and summary fields. |
| [Update-IconEditorFixtureReport.Tests.ps1](./_docs/Update-IconEditorFixtureReport.Tests.ps1.md) | Report updater for fixture-only assets. | Ensures manifest creation when requested. |
| [IconEditorPackage.Tests.ps1](./_docs/IconEditorPackage.Tests.ps1.md) | End-to-end VIP packaging validations. | Uses VIP extraction helpers and metadata checks. |

### Tools platform consistency (tests/tools)

| Suite | Validates | Notes / Key scripts |
| --- | --- | --- |
| `tests/tools/Tools.Help.Tests.ps1` | Every top-level script responds to `-?` (help). | Uses `tools/tools-manifest.json` to enumerate scripts. |
| `tests/tools/Tools.WhatIf.Tests.ps1` | `-WhatIf` should not throw for scripts that support ShouldProcess. | Uses the loader to import scripts dynamically. |
| `tests/tools/Tools.ShouldProcess.Help.Tests.ps1` | Ensures `SupportsShouldProcess` metadata matches documentation. | Prevents regression when adding new scripts. |

> **Tip:** Use `Invoke-PesterTests.ps1 -TestsPath <file>` when iterating on a single suite—most tests import modules relative to the repo root, so running from the repo root keeps path detection simple.

## Adding new suites

1. Place the `.Tests.ps1` under `tests/` (or `tests/tools/` for meta-tests).
2. Import the module/script under test inside `BeforeAll` and clean up in `AfterAll` / `AfterEach` (see existing suites for patterns).
3. Emit any temporary files into `$TestDrive` or `tests/results/_agent/<suite>` to avoid polluting the repo.
4. Update this README with a short blurb so others can discover the suite quickly.
