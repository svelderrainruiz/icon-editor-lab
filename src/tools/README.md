# Tools — Developer Reference

Purpose: Quick index for automations used by **Icon Editor Lab**. Use the tables below to jump
to a script, and the quick-start notes to see how they connect to the ISO requirements
documented in `docs/requirements/Icon-Editor-Lab_SRS.md`.

> Source: auto-generated from this repository's `tools/` directory

## Quick-start playbook

| Scenario / Requirement | Primary script(s) | Notes & emitted artifacts |
| --- | --- | --- |
| Dev-mode lifecycle (IELA-SRS-F-001) | `tools/icon-editor/Enable-DevMode.ps1`, `Disable-DevMode.ps1`, `Test-DevModeStability.ps1` | Toggle per LabVIEW version/bitness, verify `dev-mode.txt`, and log under `tests/results/_agent/icon-editor/dev-mode-run/…`. Stability harness enforces the “3 consecutive passes” gate. |
| MissingInProject suite (IELA-SRS-F-008) | `tools/icon-editor/Invoke-MissingInProjectSuite.ps1`, `Run-MipLunit-2023x64.ps1`, `Run-MipLunit-2021x64.ps1` | VI Analyzer gate runs first, then the suite, producing `_agent/reports/missing-in-project/<label>.json` plus `<label>/missing-in-project-session.json` with command/analyzer metadata. |
| Snapshot staging (IELA-SRS-INT-001) | `tools/icon-editor/Stage-IconEditorSnapshot.ps1`, `tools/Ensure-SessionIndex.ps1` | Captures a staged copy of `vendor/icon-editor`, fixture manifests, and a `session-index.json` (`icon-editor/snapshot-session@v1`). |
| LVCompare smoke / Scenario 1-4 | `tools/Run-HeadlessCompare.ps1`, `tools/TestStand-CompareHarness.ps1` | Writes `compare-report.html`, `lvcompare-capture.json`, and `session-index.json` under the chosen output root. Pair with `tools/report/Analyze-CompareReportImages.ps1` to validate screenshots. |
| Bundle export / downstream consumption | `tools/Export-LabTooling.ps1`, `tools/Get-IconEditorLabTooling.ps1`, `Resolve-IconEditorLabPath.ps1` | Creates `artifacts/icon-editor-lab-tooling.zip`, then rehydrates bundle consumers under `vendor/icon-editor-lab/bundle/`. |

### Common paths & environment hints

- `tests/results/_agent/**` — canonical location for analyzer, dev-mode, and MIP reports.
- `ICON_EDITOR_DEV_MODE_POLICY_PATH`, `MIP_EXPECTED_LV_VER`, `COMPAREVI_REPORTS_ROOT` —
  environment variables surfaced by the tooling and documented in `docs/LABVIEW_GATING.md`.
- Most orchestration scripts accept `-Verbose` and `-DryRun` so you can see the exact commands
  before running them on hardware.
- Every script in `tools/` also has a short-form Markdown reference under
  `tools/_docs/<script>.md`. Open those files (or run `Get-Help .\tools\<script>.ps1 -Full`) when
  you need parameter descriptions beyond the table below.

## Index

| Tool | Synopsis | Key Params | Path |
|---|---|---|---|
| `After-CommitActions.ps1` | Requires -Version 7.0 | `RepositoryRoot` (string), `Push` (switch), `CreatePR` (switch) | [tools/After-CommitActions.ps1](./After-CommitActions.ps1) |
| `Agent-Wait.ps1` | Fallbacks for local/non-GitHub contexts | — | [tools/Agent-Wait.ps1](./Agent-Wait.ps1) |
| `Agent-WaitHook.Profile.ps1` | Auto-end wait if marker exists and not yet ended for current startedUtc | `Reason` (string), `ExpectedSeconds` (int), `ToleranceSeconds` (int), `ResultsDir` (string), `Id` (string) | [tools/Agent-WaitHook.Profile.ps1](./Agent-WaitHook.Profile.ps1) |
| `Agent-Warmup.ps1` | One-stop warm-up command to prep local agent context for #127 (watch telemetry + session lock). | `WatchTestsPath` (string), `SessionLockTestsPath` (string), `WatchResultsDir` (string), `SchemaRoot` (string), `SkipSchemaValidation` (switch), `SkipWatch` (switch)… | [tools/Agent-Warmup.ps1](./Agent-Warmup.ps1) |
| `Analyze-CompareReportImages.ps1` | Requires -Version 7.0 | — | [tools/report/Analyze-CompareReportImages.ps1](./report/Analyze-CompareReportImages.ps1) |
| `Analyze-CompareReportImages.ps1` | Requires -Version 7.0 | — | [tools/report/Analyze-CompareReportImages.ps1](./report/Analyze-CompareReportImages.ps1) |
| `Analyze-JobLog.ps1` | Read a GitHub Actions job log (zip or text) and optionally locate a pattern. | — | [tools/Analyze-JobLog.ps1](./Analyze-JobLog.ps1) |
| `Assert-DevModeState.ps1` | Requires -Version 7.0 | — | [tools/icon-editor/Assert-DevModeState.ps1](./icon-editor/Assert-DevModeState.ps1) |
| `Assert-DevModeState.ps1` | Requires -Version 7.0 | — | [tools/icon-editor/Assert-DevModeState.ps1](./icon-editor/Assert-DevModeState.ps1) |
| `Assert-NoAmbiguousRemoteRefs.ps1` | Ensures the specified remote does not publish multiple refs (branch/tag) | — | [tools/Assert-NoAmbiguousRemoteRefs.ps1](./Assert-NoAmbiguousRemoteRefs.ps1) |
| `Assert-ValidateOutputs.ps1` | — | `ResultsRoot` (string), `RequireDerivedEnv` (switch), `RequireSessionIndex` (switch), `RequireFixtureSummary` (switch), `RequireDeltaJson` (switch) | [tools/Assert-ValidateOutputs.ps1](./Assert-ValidateOutputs.ps1) |
| `Auto-Release-WhenGreen.ps1` | Polls GitHub Actions for a green Pester run on the RC branch and, when green, merges to main and tags vX.Y.Z. | — | [tools/Auto-Release-WhenGreen.ps1](./Auto-Release-WhenGreen.ps1) |
| `Binding-MinRepro.ps1` | Binding-MinRepro.ps1 | — | [tools/Binding-MinRepro.ps1](./Binding-MinRepro.ps1) |
| `Branch-Orchestrator.ps1` | Requires -Version 7.0 | `Issue` (int), `Execute` (switch), `Base` (string), `BranchPrefix` (string) | [tools/Branch-Orchestrator.ps1](./Branch-Orchestrator.ps1) |
| `Build-Shared.ps1` | Requires -Version 7.0 | — | [tools/Build-Shared.ps1](./Build-Shared.ps1) |
| `Build-ToolsImage.ps1` | Requires -Version 7.0 | — | [tools/Build-ToolsImage.ps1](./Build-ToolsImage.ps1) |
| `Build-VSCExtension.ps1` | Preserve formatting by re-serializing; keep stable indentation | — | [tools/Build-VSCExtension.ps1](./Build-VSCExtension.ps1) |
| `Build-ValidateImage.ps1` | Requires -Version 7.0 | — | [tools/docker/Build-ValidateImage.ps1](./docker/Build-ValidateImage.ps1) |
| `Build-ValidateImage.ps1` | Requires -Version 7.0 | — | [tools/docker/Build-ValidateImage.ps1](./docker/Build-ValidateImage.ps1) |
| `Calibrate-LabVIEWBuffer.ps1` | Requires -Version 7.0 | `BufferSeconds` (object[]) | [tools/Calibrate-LabVIEWBuffer.ps1](./Calibrate-LabVIEWBuffer.ps1) |
| `Capture-LabVIEWSnapshot.ps1` | Capture a snapshot of active LabVIEW.exe processes for diagnostics. | `OutputPath` (string), `Quiet` (switch) | [tools/Capture-LabVIEWSnapshot.ps1](./Capture-LabVIEWSnapshot.ps1) |
| `Check-DocsLinks.ps1` | Quick link check across Markdown files. | — | [tools/Check-DocsLinks.ps1](./Check-DocsLinks.ps1) |
| `Check-PRMergeable.ps1` | Check a pull request mergeability state via the GitHub API. | — | [tools/Check-PRMergeable.ps1](./Check-PRMergeable.ps1) |
| `Check-TrackedBuildArtifacts.ps1` | Fails when tracked build artifacts are present in the repository. | `AllowPatterns` (string[]), `AllowListPath` (string) | [tools/Check-TrackedBuildArtifacts.ps1](./Check-TrackedBuildArtifacts.ps1) |
| `Check-WorkflowDrift.ps1` | — | `AutoFix` (switch), `Stage` (switch), `CommitMessage` (string) | [tools/Check-WorkflowDrift.ps1](./Check-WorkflowDrift.ps1) |
| `Close-LVCompare.ps1` | Runs LVCompare.exe against a pair of VIs using an explicit LabVIEW executable path (default: LabVIEW 2025 64-bit) and ensures the compare process exits. | — | [tools/Close-LVCompare.ps1](./Close-LVCompare.ps1) |
| `Close-LabVIEW.ps1` | Gracefully closes a running LabVIEW instance using the provider-agnostic CLI abstraction. | `LabVIEWExePath` (string), `MinimumSupportedLVVersion` (string) | [tools/Close-LabVIEW.ps1](./Close-LabVIEW.ps1) |
| `Collect-RunnerHealth.ps1` | Service probe (Windows and Linux) | `Enterprise` (string), `Repo` (string), `ServiceName` (string), `ResultsDir` (string), `AppendSummary` (switch), `EmitJson` (switch)… | [tools/Collect-RunnerHealth.ps1](./Collect-RunnerHealth.ps1) |
| `Compare-RefsToTemp.ps1` | — | — | [tools/Compare-RefsToTemp.ps1](./Compare-RefsToTemp.ps1) |
| `Compare-VIHistory.ps1` | — | — | [tools/Compare-VIHistory.ps1](./Compare-VIHistory.ps1) |
| `CompareVI.Tools.psd1` | — | — | [tools/CompareVI.Tools/CompareVI.Tools.psd1](./CompareVI.Tools/CompareVI.Tools.psd1) |
| `CompareVI.Tools.psd1` | — | — | [tools/CompareVI.Tools/CompareVI.Tools.psd1](./CompareVI.Tools/CompareVI.Tools.psd1) |
| `CompareVI.Tools.psm1` | — | — | [tools/CompareVI.Tools/CompareVI.Tools.psm1](./CompareVI.Tools/CompareVI.Tools.psm1) |
| `CompareVI.Tools.psm1` | — | — | [tools/CompareVI.Tools/CompareVI.Tools.psm1](./CompareVI.Tools/CompareVI.Tools.psm1) |
| `ConsoleUx.psm1` | — | — | [tools/ConsoleUx.psm1](./ConsoleUx.psm1) |
| `ConsoleWatch.ps1` | — | — | [tools/ConsoleWatch.ps1](./ConsoleWatch.ps1) |
| `ConsoleWatch.psm1` | Ensure the NDJSON file exists even if no events occur (helps consumers and artifacts) | — | [tools/ConsoleWatch.psm1](./ConsoleWatch.psm1) |
| `Debug-ChildProcesses.ps1` | Capture a snapshot of child processes (pwsh, conhost, LabVIEW, LVCompare) with memory usage. | `ResultsDir` (string), `Names` (string[]) | [tools/Debug-ChildProcesses.ps1](./Debug-ChildProcesses.ps1) |
| `Demo-FlakyRecovery.ps1` | Demonstrate Watch-Pester flaky retry recovery using the Flaky Demo test. | `DeltaJsonPath` (string), `RerunFailedAttempts` (int), `Quiet` (switch) | [tools/Demo-FlakyRecovery.ps1](./Demo-FlakyRecovery.ps1) |
| `Describe-IconEditorFixture.ps1` | Populate minimal placeholder data so downstream renderers have structured content | — | [tools/icon-editor/Describe-IconEditorFixture.ps1](./icon-editor/Describe-IconEditorFixture.ps1) |
| `Describe-IconEditorFixture.ps1` | Populate minimal placeholder data so downstream renderers have structured content | — | [tools/icon-editor/Describe-IconEditorFixture.ps1](./icon-editor/Describe-IconEditorFixture.ps1) |
| `Detect-RogueLV.ps1` | — | `ResultsDir` (string), `LookBackSeconds` (int), `FailOnRogue` (switch), `AppendToStepSummary` (switch), `Quiet` (switch), `RetryCount` (int)… | [tools/Detect-RogueLV.ps1](./Detect-RogueLV.ps1) |
| `Dev-Dashboard.ps1` | — | `Group` (string), `Html` (switch), `HtmlPath` (string), `Json` (switch), `Quiet` (switch), `Watch` (int)… | [tools/Dev-Dashboard.ps1](./Dev-Dashboard.ps1) |
| `Dev-Dashboard.psm1` | — | `Path` (string) | [tools/Dev-Dashboard.psm1](./Dev-Dashboard.psm1) |
| `Dev-WatcherManager.ps1` | — | — | [tools/Dev-WatcherManager.ps1](./Dev-WatcherManager.ps1) |
| `Diagnose-LabVIEWSetup.ps1` | Requires -Version 7.0 | `Json` (switch) | [tools/Diagnose-LabVIEWSetup.ps1](./Diagnose-LabVIEWSetup.ps1) |
| `Diff-FixtureValidationJson.ps1` | Computes a delta between two fixture validation JSON outputs. | — | [tools/Diff-FixtureValidationJson.ps1](./Diff-FixtureValidationJson.ps1) |
| `Disable-DevMode.ps1` | Requires -Version 7.0 | `RepoRoot` (string), `IconEditorRoot` (string), `Versions` (int[]), `Bitness` (int[]), `Operation` (string) | [tools/icon-editor/Disable-DevMode.ps1](./icon-editor/Disable-DevMode.ps1) |
| `Disable-DevMode.ps1` | Requires -Version 7.0 | `RepoRoot` (string), `IconEditorRoot` (string), `Versions` (int[]), `Bitness` (int[]), `Operation` (string) | [tools/icon-editor/Disable-DevMode.ps1](./icon-editor/Disable-DevMode.ps1) |
| `Dispatch-WithSample.ps1` | Dispatch a workflow with a freshly-generated sample_id. | — | [tools/Dispatch-WithSample.ps1](./Dispatch-WithSample.ps1) |
| `Emit-LVClosureCrumb.ps1` | Emit LV closure telemetry crumbs when enabled. | `ResultsDir` (string), `Phase` (string), `ProcessNames` (string[]) | [tools/Emit-LVClosureCrumb.ps1](./Emit-LVClosureCrumb.ps1) |
| `Enable-DevMode.ps1` | Requires -Version 7.0 | `RepoRoot` (string), `IconEditorRoot` (string), `Versions` (int[]), `Bitness` (int[]), `Operation` (string) | [tools/icon-editor/Enable-DevMode.ps1](./icon-editor/Enable-DevMode.ps1) |
| `Enable-DevMode.ps1` | Requires -Version 7.0 | `RepoRoot` (string), `IconEditorRoot` (string), `Versions` (int[]), `Bitness` (int[]), `Operation` (string) | [tools/icon-editor/Enable-DevMode.ps1](./icon-editor/Enable-DevMode.ps1) |
| `Ensure-SessionIndex.ps1` | Minimal step summary | — | [tools/Ensure-SessionIndex.ps1](./Ensure-SessionIndex.ps1) |
| `Export-LabTooling.ps1` | Requires -Version 7.0 | `Destination` (string), `IncludePaths` (string[]) | [tools/Export-LabTooling.ps1](./Export-LabTooling.ps1) |
| `Find-VIComparisonCandidates.ps1` | Requires -Version 7.0 | `RepoPath` (string), `BaseRef` (string), `HeadRef` (string), `MaxCommits` (int), `Kinds` (string[]) | [tools/compare/Find-VIComparisonCandidates.ps1](./compare/Find-VIComparisonCandidates.ps1) |
| `Find-VIComparisonCandidates.ps1` | Requires -Version 7.0 | `RepoPath` (string), `BaseRef` (string), `HeadRef` (string), `MaxCommits` (int), `Kinds` (string[]) | [tools/compare/Find-VIComparisonCandidates.ps1](./compare/Find-VIComparisonCandidates.ps1) |
| `Follow-OrchestratedRun.ps1` | — | — | [tools/Follow-OrchestratedRun.ps1](./Follow-OrchestratedRun.ps1) |
| `Follow-PesterArtifacts.ps1` | — | — | [tools/Follow-PesterArtifacts.ps1](./Follow-PesterArtifacts.ps1) |
| `Force-CloseLabVIEW.ps1` | — | `ProcessName` (string[]) | [tools/Force-CloseLabVIEW.ps1](./Force-CloseLabVIEW.ps1) |
| `GCli.psm1` | Requires -Version 7.0 | — | [tools/GCli.psm1](./GCli.psm1) |
| `Generate-ActionOutputsDoc.ps1` | Generate markdown documentation for composite action inputs & outputs. | — | [tools/Generate-ActionOutputsDoc.ps1](./Generate-ActionOutputsDoc.ps1) |
| `Get-BranchProtectionRequiredChecks.ps1` | Requires -Version 7.0 | — | [tools/Get-BranchProtectionRequiredChecks.ps1](./Get-BranchProtectionRequiredChecks.ps1) |
| `Get-FileSha256.ps1` | Compute the SHA-256 digest for a file. | — | [tools/Get-FileSha256.ps1](./Get-FileSha256.ps1) |
| `Get-PRVIDiffManifest.ps1` | Generates a manifest of VI path pairs for pull-request comparisons. | — | [tools/Get-PRVIDiffManifest.ps1](./Get-PRVIDiffManifest.ps1) |
| `Get-PesterVersion.ps1` | — | `EmitEnv` (switch), `EmitOutput` (switch) | [tools/Get-PesterVersion.ps1](./Get-PesterVersion.ps1) |
| `Get-StandingPriority.ps1` | Requires -Version 7.0 | `Plain` (switch), `CacheOnly` (switch), `NoCacheUpdate` (switch) | [tools/Get-StandingPriority.ps1](./Get-StandingPriority.ps1) |
| `Get-VICompareMetadata.ps1` | Captures LVCompare metadata (status, categories, headings) for a VI pair. | — | [tools/Get-VICompareMetadata.ps1](./Get-VICompareMetadata.ps1) |
| `Guard-LabVIEWPersistence.ps1` | Guard to observe LabVIEW/LVCompare process presence around phases. | `ResultsDir` (string) | [tools/Guard-LabVIEWPersistence.ps1](./Guard-LabVIEWPersistence.ps1) |
| `IconEditorDevMode.psm1` | Requires -Version 7.0 | `StartPath` (string) | [tools/icon-editor/IconEditorDevMode.psm1](./icon-editor/IconEditorDevMode.psm1) |
| `IconEditorDevMode.psm1` | Requires -Version 7.0 | `StartPath` (string) | [tools/icon-editor/IconEditorDevMode.psm1](./icon-editor/IconEditorDevMode.psm1) |
| `IconEditorPackage.psm1` | Requires -Version 7.0 | `WorkspaceRoot` (string) | [tools/icon-editor/IconEditorPackage.psm1](./icon-editor/IconEditorPackage.psm1) |
| `IconEditorPackage.psm1` | Requires -Version 7.0 | `WorkspaceRoot` (string) | [tools/icon-editor/IconEditorPackage.psm1](./icon-editor/IconEditorPackage.psm1) |
| `IconEditorPackaging.psm1` | Provides a structured setup/main/cleanup flow for packaging the Icon Editor VI. | — | [tools/vendor/IconEditorPackaging.psm1](./vendor/IconEditorPackaging.psm1) |
| `IconEditorPackaging.psm1` | Provides a structured setup/main/cleanup flow for packaging the Icon Editor VI. | — | [tools/vendor/IconEditorPackaging.psm1](./vendor/IconEditorPackaging.psm1) |
| `Import-HandoffState.ps1` | Requires -Version 7.0 | `HandoffDir` (string) | [tools/priority/Import-HandoffState.ps1](./priority/Import-HandoffState.ps1) |
| `Import-HandoffState.ps1` | Requires -Version 7.0 | `HandoffDir` (string) | [tools/priority/Import-HandoffState.ps1](./priority/Import-HandoffState.ps1) |
| `Inspect-HistorySignalStats.ps1` | Requires -Version 7.0 | `TargetPath` (string), `StartRef` (string), `MaxPairs` (int), `MaxSignalPairs` (int) | [tools/Inspect-HistorySignalStats.ps1](./Inspect-HistorySignalStats.ps1) |
| `Inspect-MissingProjectItems.ps1` | Requires -Version 7.0 | `ProjectPath` (string), `OutputPath` (string), `RepoRoot` (string) | [tools/icon-editor/Inspect-MissingProjectItems.ps1](./icon-editor/Inspect-MissingProjectItems.ps1) |
| `Inspect-MissingProjectItems.ps1` | Requires -Version 7.0 | `ProjectPath` (string), `OutputPath` (string), `RepoRoot` (string) | [tools/icon-editor/Inspect-MissingProjectItems.ps1](./icon-editor/Inspect-MissingProjectItems.ps1) |
| `Invoke-CompareCli.ps1` | — | — | [tools/Invoke-CompareCli.ps1](./Invoke-CompareCli.ps1) |
| `Invoke-DevDashboard.ps1` | — | — | [tools/Invoke-DevDashboard.ps1](./Invoke-DevDashboard.ps1) |
| `Invoke-FixtureViDiffs.ps1` | — | — | [tools/icon-editor/Invoke-FixtureViDiffs.ps1](./icon-editor/Invoke-FixtureViDiffs.ps1) |
| `Invoke-FixtureViDiffs.ps1` | — | — | [tools/icon-editor/Invoke-FixtureViDiffs.ps1](./icon-editor/Invoke-FixtureViDiffs.ps1) |
| `Invoke-IconEditorBuild.ps1` | Requires -Version 7.0 | — | [tools/icon-editor/Invoke-IconEditorBuild.ps1](./icon-editor/Invoke-IconEditorBuild.ps1) |
| `Invoke-IconEditorBuild.ps1` | Requires -Version 7.0 | — | [tools/icon-editor/Invoke-IconEditorBuild.ps1](./icon-editor/Invoke-IconEditorBuild.ps1) |
| `Invoke-IconEditorSnapshotFromRepo.ps1` | Requires -Version 7.0 | — | [tools/icon-editor/Invoke-IconEditorSnapshotFromRepo.ps1](./icon-editor/Invoke-IconEditorSnapshotFromRepo.ps1) |
| `Invoke-IconEditorSnapshotFromRepo.ps1` | Requires -Version 7.0 | — | [tools/icon-editor/Invoke-IconEditorSnapshotFromRepo.ps1](./icon-editor/Invoke-IconEditorSnapshotFromRepo.ps1) |
| `Invoke-JsonSchemaLite.ps1` | When the supplied schema declares a const value that does not match the JSON payload's | — | [tools/Invoke-JsonSchemaLite.ps1](./Invoke-JsonSchemaLite.ps1) |
| `Invoke-LVCompare.ps1` | Deterministic driver for LVCompare.exe with capture and optional HTML report. | — | [tools/Invoke-LVCompare.ps1](./Invoke-LVCompare.ps1) |
| `Invoke-LabelsSync.ps1` | — | — | [tools/Invoke-LabelsSync.ps1](./Invoke-LabelsSync.ps1) |
| `Invoke-LintDotSourcing.ps1` | Helper wrapper for dot-sourcing lint task that tolerates missing script. | — | [tools/Invoke-LintDotSourcing.ps1](./Invoke-LintDotSourcing.ps1) |
| `Invoke-MissingInProjectSuite.ps1` | Runs the MissingInProject Pester suite end-to-end with optional VI Analyzer gating. | — | [tools/icon-editor/Invoke-MissingInProjectSuite.ps1](./icon-editor/Invoke-MissingInProjectSuite.ps1) |
| `Invoke-MissingInProjectSuite.ps1` | Runs the MissingInProject Pester suite end-to-end with optional VI Analyzer gating. | — | [tools/icon-editor/Invoke-MissingInProjectSuite.ps1](./icon-editor/Invoke-MissingInProjectSuite.ps1) |
| `Invoke-OneShotTask.ps1` | Runs the common VS Code icon-editor one-shot task from the CLI. | — | [tools/icon-editor/Invoke-OneShotTask.ps1](./icon-editor/Invoke-OneShotTask.ps1) |
| `Invoke-OneShotTask.ps1` | Runs the common VS Code icon-editor one-shot task from the CLI. | — | [tools/icon-editor/Invoke-OneShotTask.ps1](./icon-editor/Invoke-OneShotTask.ps1) |
| `Invoke-PRVIHistory.ps1` | Runs Compare-VIHistory for each VI referenced in a diff manifest. | — | [tools/Invoke-PRVIHistory.ps1](./Invoke-PRVIHistory.ps1) |
| `Invoke-PRVIStaging.ps1` | Stages VI pairs from a diff manifest using Stage-CompareInputs. | — | [tools/Invoke-PRVIStaging.ps1](./Invoke-PRVIStaging.ps1) |
| `Invoke-ProviderComparison.ps1` | Compares VIPM operations across provider backends and records telemetry. | `SkipMissingProviders`, `Scenario`, `Providers`, `ScenarioFile` | [tools/Vipm/Invoke-ProviderComparison.ps1](./Vipm/Invoke-ProviderComparison.ps1) |
| `Invoke-ProviderComparison.ps1` | Compares VIPM operations across provider backends and records telemetry. | `SkipMissingProviders`, `Scenario`, `Providers`, `ScenarioFile` | [tools/Vipm/Invoke-ProviderComparison.ps1](./Vipm/Invoke-ProviderComparison.ps1) |
| `Invoke-VIAnalyzer.ps1` | Runs the LabVIEW VI Analyzer headlessly via LabVIEWCLI and captures telemetry. | — | [tools/icon-editor/Invoke-VIAnalyzer.ps1](./icon-editor/Invoke-VIAnalyzer.ps1) |
| `Invoke-VIAnalyzer.ps1` | Runs the LabVIEW VI Analyzer headlessly via LabVIEWCLI and captures telemetry. | — | [tools/icon-editor/Invoke-VIAnalyzer.ps1](./icon-editor/Invoke-VIAnalyzer.ps1) |
| `Invoke-VIComparisonFromCommit.ps1` | Requires -Version 7.0 | — | [tools/icon-editor/Invoke-VIComparisonFromCommit.ps1](./icon-editor/Invoke-VIComparisonFromCommit.ps1) |
| `Invoke-VIComparisonFromCommit.ps1` | Requires -Version 7.0 | — | [tools/icon-editor/Invoke-VIComparisonFromCommit.ps1](./icon-editor/Invoke-VIComparisonFromCommit.ps1) |
| `Invoke-VIDiffSweep.ps1` | Requires -Version 7.0 | — | [tools/icon-editor/Invoke-VIDiffSweep.ps1](./icon-editor/Invoke-VIDiffSweep.ps1) |
| `Invoke-VIDiffSweep.ps1` | Requires -Version 7.0 | — | [tools/icon-editor/Invoke-VIDiffSweep.ps1](./icon-editor/Invoke-VIDiffSweep.ps1) |
| `Invoke-VIDiffSweepStrong.ps1` | Requires -Version 7.0 | — | [tools/icon-editor/Invoke-VIDiffSweepStrong.ps1](./icon-editor/Invoke-VIDiffSweepStrong.ps1) |
| `Invoke-VIDiffSweepStrong.ps1` | Requires -Version 7.0 | — | [tools/icon-editor/Invoke-VIDiffSweepStrong.ps1](./icon-editor/Invoke-VIDiffSweepStrong.ps1) |
| `Invoke-ValidateLocal.ps1` | Runs a self-hosted Validate flow locally, including fixture report generation, | — | [tools/icon-editor/Invoke-ValidateLocal.ps1](./icon-editor/Invoke-ValidateLocal.ps1) |
| `Invoke-ValidateLocal.ps1` | Runs a self-hosted Validate flow locally, including fixture report generation, | — | [tools/icon-editor/Invoke-ValidateLocal.ps1](./icon-editor/Invoke-ValidateLocal.ps1) |
| `Invoke-VipmCliBuild.ps1` | Requires -Version 7.0 | `RepoRoot` (string), `IconEditorRoot` (string), `RepoSlug` (string), `MinimumSupportedLVVersion` (int), `PackageMinimumSupportedLVVersion` (int), `PackageSupportedBitness` (int)… | [tools/icon-editor/Invoke-VipmCliBuild.ps1](./icon-editor/Invoke-VipmCliBuild.ps1) |
| `Invoke-VipmCliBuild.ps1` | Requires -Version 7.0 | `RepoRoot` (string), `IconEditorRoot` (string), `RepoSlug` (string), `MinimumSupportedLVVersion` (int), `PackageMinimumSupportedLVVersion` (int), `PackageSupportedBitness` (int)… | [tools/icon-editor/Invoke-VipmCliBuild.ps1](./icon-editor/Invoke-VipmCliBuild.ps1) |
| `Invoke-VipmDependencies.ps1` | Requires -Version 7.0 | `MinimumSupportedLVVersion` (string), `VIP_LVVersion` (string), `SupportedBitness` (string[]) | [tools/icon-editor/Invoke-VipmDependencies.ps1](./icon-editor/Invoke-VipmDependencies.ps1) |
| `Invoke-VipmDependencies.ps1` | Requires -Version 7.0 | `MinimumSupportedLVVersion` (string), `VIP_LVVersion` (string), `SupportedBitness` (string[]) | [tools/icon-editor/Invoke-VipmDependencies.ps1](./icon-editor/Invoke-VipmDependencies.ps1) |
| `Invoke-WithTranscript.ps1` | Requires -Version 7.0 | — | [tools/Invoke-WithTranscript.ps1](./Invoke-WithTranscript.ps1) |
| `LabVIEWCli.psm1` | — | `StartPath` (string) | [tools/LabVIEWCli.psm1](./LabVIEWCli.psm1) |
| `LabVIEWPidTracker.psm1` | — | `Context` (object) | [tools/LabVIEWPidTracker.psm1](./LabVIEWPidTracker.psm1) |
| `Link-RequirementToAdr.ps1` | Update requirement Traceability section. | — | [tools/Link-RequirementToAdr.ps1](./Link-RequirementToAdr.ps1) |
| `Lint-DotSourcing.ps1` | — | `WarnOnly` (switch) | [tools/Lint-DotSourcing.ps1](./Lint-DotSourcing.ps1) |
| `Lint-InlineIfInFormat.ps1` | Detect the PowerShell format operator specifically: "..." -f ... | — | [tools/Lint-InlineIfInFormat.ps1](./Lint-InlineIfInFormat.ps1) |
| `Lint-LoopDeterminism.Shim.ps1` | Robust wrapper for Lint-LoopDeterminism.ps1 that tolerates mixed/positional args | `Paths` (string[]), `PathsList` (string) | [tools/Lint-LoopDeterminism.Shim.ps1](./Lint-LoopDeterminism.Shim.ps1) |
| `Lint-LoopDeterminism.ps1` | Lint for CI loop determinism patterns in workflow/script content. | — | [tools/Lint-LoopDeterminism.ps1](./Lint-LoopDeterminism.ps1) |
| `Lint-Markdown.ps1` | — | `All` (switch), `BaseRef` (string) | [tools/Lint-Markdown.ps1](./Lint-Markdown.ps1) |
| `Local-RunTests.ps1` | Ensure local-friendly environment (no session locks or GH-only toggles) | — | [tools/Local-RunTests.ps1](./Local-RunTests.ps1) |
| `Local-Runbook.ps1` | Default phases for local sanity runs | — | [tools/Local-Runbook.ps1](./Local-Runbook.ps1) |
| `Measure-ResponseWindow.ps1` | Emit machine-friendly line | — | [tools/Measure-ResponseWindow.ps1](./Measure-ResponseWindow.ps1) |
| `Measure-VIAnalyzerDeadTime.ps1` | Requires -Version 7.0 | `RepoRoot` (string) | [tools/icon-editor/Measure-VIAnalyzerDeadTime.ps1](./icon-editor/Measure-VIAnalyzerDeadTime.ps1) |
| `Measure-VIAnalyzerDeadTime.ps1` | Requires -Version 7.0 | `RepoRoot` (string) | [tools/icon-editor/Measure-VIAnalyzerDeadTime.ps1](./icon-editor/Measure-VIAnalyzerDeadTime.ps1) |
| `MipScenarioHelpers.psm1` | Requires -Version 7.0 | `PathCandidate` (string), `BasePath` (string) | [tools/icon-editor/MipScenarioHelpers.psm1](./icon-editor/MipScenarioHelpers.psm1) |
| `MipScenarioHelpers.psm1` | Requires -Version 7.0 | `PathCandidate` (string), `BasePath` (string) | [tools/icon-editor/MipScenarioHelpers.psm1](./icon-editor/MipScenarioHelpers.psm1) |
| `New-Adr.ps1` | ADR $($adrId): $Title | — | [tools/New-Adr.ps1](./New-Adr.ps1) |
| `New-HostPrepReport.ps1` | Requires -Version 7.0 | `Label` (string) | [tools/report/New-HostPrepReport.ps1](./report/New-HostPrepReport.ps1) |
| `New-HostPrepReport.ps1` | Requires -Version 7.0 | `Label` (string) | [tools/report/New-HostPrepReport.ps1](./report/New-HostPrepReport.ps1) |
| `New-LVCompareConfig.ps1` | Requires -Version 7.0 | `OutputPath` (string), `NonInteractive` (switch), `Force` (switch), `Probe` (switch), `LabVIEWExePath` (string), `LVComparePath` (string)… | [tools/New-LVCompareConfig.ps1](./New-LVCompareConfig.ps1) |
| `New-LVCompareReport.ps1` | Requires -Version 7.0 | `Label` (string) | [tools/report/New-LVCompareReport.ps1](./report/New-LVCompareReport.ps1) |
| `New-LVCompareReport.ps1` | Requires -Version 7.0 | `Label` (string) | [tools/report/New-LVCompareReport.ps1](./report/New-LVCompareReport.ps1) |
| `New-MissingInProjectReport.ps1` | Requires -Version 7.0 | `Label` (string) | [tools/report/New-MissingInProjectReport.ps1](./report/New-MissingInProjectReport.ps1) |
| `New-MissingInProjectReport.ps1` | Requires -Version 7.0 | `Label` (string) | [tools/report/New-MissingInProjectReport.ps1](./report/New-MissingInProjectReport.ps1) |
| `New-SampleId.ps1` | Generate a sample_id for workflow_dispatch runs. | `Prefix` (string) | [tools/New-SampleId.ps1](./New-SampleId.ps1) |
| `New-UnitTestReport.ps1` | Requires -Version 7.0 | `Label` (string) | [tools/report/New-UnitTestReport.ps1](./report/New-UnitTestReport.ps1) |
| `New-UnitTestReport.ps1` | Requires -Version 7.0 | `Label` (string) | [tools/report/New-UnitTestReport.ps1](./report/New-UnitTestReport.ps1) |
| `Notify-Demo.ps1` | Simple demo notify script. Writes a concise line plus environment reflection. | `Status` (string), `Failed` (int), `Tests` (int), `Skipped` (int), `RunSequence` (int), `Classification` (string) | [tools/Notify-Demo.ps1](./Notify-Demo.ps1) |
| `Once-Guard.psm1` | File-backed single-execution guard for multi-step workflows. | — | [tools/Once-Guard.psm1](./Once-Guard.psm1) |
| `OneButton-CI.ps1` | One-button end-to-end CI trigger and artifact post-processing for #127. | `Ref` (string) | [tools/OneButton-CI.ps1](./OneButton-CI.ps1) |
| `PackedLibraryBuild.psm1` | Helper for orchestrating g-cli packed library builds across bitness targets. | — | [tools/vendor/PackedLibraryBuild.psm1](./vendor/PackedLibraryBuild.psm1) |
| `PackedLibraryBuild.psm1` | Helper for orchestrating g-cli packed library builds across bitness targets. | — | [tools/vendor/PackedLibraryBuild.psm1](./vendor/PackedLibraryBuild.psm1) |
| `Parse-CompareExec.ps1` | — | — | [tools/Parse-CompareExec.ps1](./Parse-CompareExec.ps1) |
| `Post-IssueComment.ps1` | Requires -Version 7.0 | — | [tools/Post-IssueComment.ps1](./Post-IssueComment.ps1) |
| `Post-Run-Cleanup.ps1` | Post-run cleanup orchestrator. Aggregates cleanup requests and ensures close | `CloseLabVIEW` (switch), `CloseLVCompare` (switch) | [tools/Post-Run-Cleanup.ps1](./Post-Run-Cleanup.ps1) |
| `PostRunRequests.psm1` | — | — | [tools/PostRun/PostRunRequests.psm1](./PostRun/PostRunRequests.psm1) |
| `PostRunRequests.psm1` | — | — | [tools/PostRun/PostRunRequests.psm1](./PostRun/PostRunRequests.psm1) |
| `PrePush-Checks.ps1` | Local pre-push checks: run actionlint against workflows. | — | [tools/PrePush-Checks.ps1](./PrePush-Checks.ps1) |
| `Prepare-FixtureViDiffs.ps1` | — | `ReportPath` (string), `BaselineManifestPath` (string), `BaselineFixturePath` (string), `OutputDir` (string), `ResourceOverlayRoot` (string) | [tools/icon-editor/Prepare-FixtureViDiffs.ps1](./icon-editor/Prepare-FixtureViDiffs.ps1) |
| `Prepare-FixtureViDiffs.ps1` | — | `ReportPath` (string), `BaselineManifestPath` (string), `BaselineFixturePath` (string), `OutputDir` (string), `ResourceOverlayRoot` (string) | [tools/icon-editor/Prepare-FixtureViDiffs.ps1](./icon-editor/Prepare-FixtureViDiffs.ps1) |
| `Prepare-LabVIEWHost.ps1` | Requires -Version 7.0 | — | [tools/icon-editor/Prepare-LabVIEWHost.ps1](./icon-editor/Prepare-LabVIEWHost.ps1) |
| `Prepare-LabVIEWHost.ps1` | Requires -Version 7.0 | — | [tools/icon-editor/Prepare-LabVIEWHost.ps1](./icon-editor/Prepare-LabVIEWHost.ps1) |
| `Prepare-OverlayFromRepo.ps1` | Requires -Version 7.0 | `RepoPath` (string), `BaseRef` (string), `HeadRef` (string), `OverlayRoot` (string), `IncludePatterns` (string[]) | [tools/icon-editor/Prepare-OverlayFromRepo.ps1](./icon-editor/Prepare-OverlayFromRepo.ps1) |
| `Prepare-OverlayFromRepo.ps1` | Requires -Version 7.0 | `RepoPath` (string), `BaseRef` (string), `HeadRef` (string), `OverlayRoot` (string), `IncludePatterns` (string[]) | [tools/icon-editor/Prepare-OverlayFromRepo.ps1](./icon-editor/Prepare-OverlayFromRepo.ps1) |
| `Prepare-StandingCommit.ps1` | Requires -Version 7.0 | `RepositoryRoot` (string), `AutoCommit` (switch) | [tools/Prepare-StandingCommit.ps1](./Prepare-StandingCommit.ps1) |
| `Prepare-UnitTestState.ps1` | Requires -Version 7.0 | `Validate` (switch) | [tools/icon-editor/Prepare-UnitTestState.ps1](./icon-editor/Prepare-UnitTestState.ps1) |
| `Prepare-UnitTestState.ps1` | Requires -Version 7.0 | `Validate` (switch) | [tools/icon-editor/Prepare-UnitTestState.ps1](./icon-editor/Prepare-UnitTestState.ps1) |
| `Prepare-VipViDiffRequests.ps1` | Requires -Version 7.0 | — | [tools/icon-editor/Prepare-VipViDiffRequests.ps1](./icon-editor/Prepare-VipViDiffRequests.ps1) |
| `Prepare-VipViDiffRequests.ps1` | Requires -Version 7.0 | — | [tools/icon-editor/Prepare-VipViDiffRequests.ps1](./icon-editor/Prepare-VipViDiffRequests.ps1) |
| `Prime-LVCompare.ps1` | Runs LVCompare.exe against two VIs to validate CLI readiness and emit diff breadcrumbs. | `nofppos` | [tools/Prime-LVCompare.ps1](./Prime-LVCompare.ps1) |
| `Print-AgentHandoff.ps1` | — | `ApplyToggles` (switch), `OpenDashboard` (switch), `AutoTrim` (switch), `Group` (string), `ResultsRoot` (string) | [tools/Print-AgentHandoff.ps1](./Print-AgentHandoff.ps1) |
| `Print-PesterTopFailures.ps1` | — | `ResultsDir` (string), `Top` (int), `PassThru` (switch) | [tools/Print-PesterTopFailures.ps1](./Print-PesterTopFailures.ps1) |
| `Print-ToolVersions.ps1` | — | — | [tools/Print-ToolVersions.ps1](./Print-ToolVersions.ps1) |
| `Provider.psm1` | Requires -Version 7.0 | — | [tools/providers/gcli/Provider.psm1](./providers/gcli/Provider.psm1) |
| `Provider.psm1` | Requires -Version 7.0 | — | [tools/providers/gcli/Provider.psm1](./providers/gcli/Provider.psm1) |
| `Provider.psm1` | Requires -Version 7.0 | — | [tools/providers/gcli/Provider.psm1](./providers/gcli/Provider.psm1) |
| `Provider.psm1` | Requires -Version 7.0 | — | [tools/providers/vipm-gcli/Provider.psm1](./providers/vipm-gcli/Provider.psm1) |
| `Provider.psm1` | Requires -Version 7.0 | — | [tools/providers/vipm-gcli/Provider.psm1](./providers/vipm-gcli/Provider.psm1) |
| `Provider.psm1` | Requires -Version 7.0 | — | [tools/providers/vipm-gcli/Provider.psm1](./providers/vipm-gcli/Provider.psm1) |
| `Provider.psm1` | Requires -Version 7.0 | — | [tools/providers/vipm/Provider.psm1](./providers/vipm/Provider.psm1) |
| `Provider.psm1` | Requires -Version 7.0 | — | [tools/providers/vipm/Provider.psm1](./providers/vipm/Provider.psm1) |
| `Provider.psm1` | Requires -Version 7.0 | — | [tools/providers/vipm/Provider.psm1](./providers/vipm/Provider.psm1) |
| `Provider.psm1` | — | `Value` (bool) | [tools/providers/labviewcli/Provider.psm1](./providers/labviewcli/Provider.psm1) |
| `Provider.psm1` | — | `Value` (bool) | [tools/providers/labviewcli/Provider.psm1](./providers/labviewcli/Provider.psm1) |
| `Provider.psm1` | — | `Value` (bool) | [tools/providers/labviewcli/Provider.psm1](./providers/labviewcli/Provider.psm1) |
| `Publish-Cli.ps1` | Use system tar; on Windows this is bsdtar. Permissions for linux/osx binaries | — | [tools/Publish-Cli.ps1](./Publish-Cli.ps1) |
| `Publish-LocalArtifacts.ps1` | Requires -Version 7.0 | `ArtifactsRoot` (string), `GhTokenPath` (string), `ReleaseTag` (string), `ReleaseName` (string), `SkipUpload` (switch) | [tools/icon-editor/Publish-LocalArtifacts.ps1](./icon-editor/Publish-LocalArtifacts.ps1) |
| `Publish-LocalArtifacts.ps1` | Requires -Version 7.0 | `ArtifactsRoot` (string), `GhTokenPath` (string), `ReleaseTag` (string), `ReleaseName` (string), `SkipUpload` (switch) | [tools/icon-editor/Publish-LocalArtifacts.ps1](./icon-editor/Publish-LocalArtifacts.ps1) |
| `Publish-VICompareSummary.ps1` | — | — | [tools/Publish-VICompareSummary.ps1](./Publish-VICompareSummary.ps1) |
| `Quick-DispatcherSmoke.ps1` | Quick local smoke test for Invoke-PesterTests.ps1. | — | [tools/Quick-DispatcherSmoke.ps1](./Quick-DispatcherSmoke.ps1) |
| `Quick-VerifyCompare.ps1` | Quick local verification of Compare VI action outputs (seconds + nanoseconds) without running full Pester. | `Base` (string), `Head` (string), `Same` (switch), `ShowSummary` (switch) | [tools/Quick-VerifyCompare.ps1](./Quick-VerifyCompare.ps1) |
| `Read-EnvSettings.ps1` | — | `Json` (switch) | [tools/Read-EnvSettings.ps1](./Read-EnvSettings.ps1) |
| `Render-IconEditorFixtureReport.ps1` | Requires -Version 7.0 | `ReportPath` (string), `FixturePath` (string), `OutputPath` (string), `UpdateDoc` (switch) | [tools/icon-editor/Render-IconEditorFixtureReport.ps1](./icon-editor/Render-IconEditorFixtureReport.ps1) |
| `Render-IconEditorFixtureReport.ps1` | Requires -Version 7.0 | `ReportPath` (string), `FixturePath` (string), `OutputPath` (string), `UpdateDoc` (switch) | [tools/icon-editor/Render-IconEditorFixtureReport.ps1](./icon-editor/Render-IconEditorFixtureReport.ps1) |
| `Render-Report.Mock.ps1` | — | — | [tools/Render-Report.Mock.ps1](./Render-Report.Mock.ps1) |
| `Render-RunSummary.ps1` | — | — | [tools/Render-RunSummary.ps1](./Render-RunSummary.ps1) |
| `Render-VIHistoryReport.ps1` | — | — | [tools/Render-VIHistoryReport.ps1](./Render-VIHistoryReport.ps1) |
| `Render-ViComparisonReport.ps1` | Requires -Version 7.0 | — | [tools/icon-editor/Render-ViComparisonReport.ps1](./icon-editor/Render-ViComparisonReport.ps1) |
| `Render-ViComparisonReport.ps1` | Requires -Version 7.0 | — | [tools/icon-editor/Render-ViComparisonReport.ps1](./icon-editor/Render-ViComparisonReport.ps1) |
| `Replay-ApplyVipcJob.ps1` | Replays the "Apply VIPC Dependencies" job locally for diagnosis. | — | [tools/icon-editor/Replay-ApplyVipcJob.ps1](./icon-editor/Replay-ApplyVipcJob.ps1) |
| `Replay-ApplyVipcJob.ps1` | Replays the "Apply VIPC Dependencies" job locally for diagnosis. | — | [tools/icon-editor/Replay-ApplyVipcJob.ps1](./icon-editor/Replay-ApplyVipcJob.ps1) |
| `Replay-BuildVipJob.ps1` | Replays the GitHub Actions "Build VI Package" job locally. | — | [tools/icon-editor/Replay-BuildVipJob.ps1](./icon-editor/Replay-BuildVipJob.ps1) |
| `Replay-BuildVipJob.ps1` | Replays the GitHub Actions "Build VI Package" job locally. | — | [tools/icon-editor/Replay-BuildVipJob.ps1](./icon-editor/Replay-BuildVipJob.ps1) |
| `Reset-IconEditorWorkspace.ps1` | Requires -Version 7.0 | `RepoRoot` (string), `IconEditorRoot` (string), `Versions` (int[]), `Bitness` (int[]), `LabVIEWProject` (string), `BuildSpec` (string)… | [tools/icon-editor/Reset-IconEditorWorkspace.ps1](./icon-editor/Reset-IconEditorWorkspace.ps1) |
| `Reset-IconEditorWorkspace.ps1` | Requires -Version 7.0 | `RepoRoot` (string), `IconEditorRoot` (string), `Versions` (int[]), `Bitness` (int[]), `LabVIEWProject` (string), `BuildSpec` (string)… | [tools/icon-editor/Reset-IconEditorWorkspace.ps1](./icon-editor/Reset-IconEditorWorkspace.ps1) |
| `Run-CompareSequence.ps1` | Local lock (filesystem) to emulate 4-wire control | — | [tools/Run-CompareSequence.ps1](./Run-CompareSequence.ps1) |
| `Run-DX.ps1` | Shared / Pester parameters | — | [tools/Run-DX.ps1](./Run-DX.ps1) |
| `Run-FixtureValidation.ps1` | — | `NoticeOnly` (switch) | [tools/Run-FixtureValidation.ps1](./Run-FixtureValidation.ps1) |
| `Run-HandoffTests.ps1` | Requires -Version 7.0 | — | [tools/priority/Run-HandoffTests.ps1](./priority/Run-HandoffTests.ps1) |
| `Run-HandoffTests.ps1` | Requires -Version 7.0 | — | [tools/priority/Run-HandoffTests.ps1](./priority/Run-HandoffTests.ps1) |
| `Run-HeadlessCompare.ps1` | Canonical headless entry point for VI compares (CLI-first, timeout-aware). | — | [tools/Run-HeadlessCompare.ps1](./Run-HeadlessCompare.ps1) |
| `Run-LocalBackbone.ps1` | — | — | [tools/Run-LocalBackbone.ps1](./Run-LocalBackbone.ps1) |
| `Run-LocalDiffSession.ps1` | Requires -Version 7.0 | — | [tools/Run-LocalDiffSession.ps1](./Run-LocalDiffSession.ps1) |
| `Run-LoopDeterminism.ps1` | — | `FailOnViolation` (switch) | [tools/Run-LoopDeterminism.ps1](./Run-LoopDeterminism.ps1) |
| `Run-MipLunit-2021x64.ps1` | Orchestrates Scenario 6b (legacy MIP 2021 x64 + LUnit) end-to-end. | `ProjectPath` (string), `AnalyzerConfigPath` (string), `ResultsPath` (string), `AutoCloseWrongLV` (switch), `DryRun` (switch) | [tools/icon-editor/Run-MipLunit-2021x64.ps1](./icon-editor/Run-MipLunit-2021x64.ps1) |
| `Run-MipLunit-2021x64.ps1` | Orchestrates Scenario 6b (legacy MIP 2021 x64 + LUnit) end-to-end. | `ProjectPath` (string), `AnalyzerConfigPath` (string), `ResultsPath` (string), `AutoCloseWrongLV` (switch), `DryRun` (switch) | [tools/icon-editor/Run-MipLunit-2021x64.ps1](./icon-editor/Run-MipLunit-2021x64.ps1) |
| `Run-MipLunit-2023x64.ps1` | Orchestrates Scenario 6a (MIP 2023 x64 + LUnit) end-to-end. | `ProjectPath` (string), `AnalyzerConfigPath` (string), `ResultsPath` (string), `AutoCloseWrongLV` (switch), `DryRun` (switch) | [tools/icon-editor/Run-MipLunit-2023x64.ps1](./icon-editor/Run-MipLunit-2023x64.ps1) |
| `Run-MipLunit-2023x64.ps1` | Orchestrates Scenario 6a (MIP 2023 x64 + LUnit) end-to-end. | `ProjectPath` (string), `AnalyzerConfigPath` (string), `ResultsPath` (string), `AutoCloseWrongLV` (switch), `DryRun` (switch) | [tools/icon-editor/Run-MipLunit-2023x64.ps1](./icon-editor/Run-MipLunit-2023x64.ps1) |
| `Run-NonLVChecksInDocker.ps1` | Runs non-LabVIEW validation checks (actionlint, markdownlint, docs links, workflow drift) | — | [tools/Run-NonLVChecksInDocker.ps1](./Run-NonLVChecksInDocker.ps1) |
| `Run-OneButtonValidate.ps1` | — | `Stage` (switch), `Commit` (switch), `Push` (switch), `CreatePR` (switch), `OpenResults` (switch) | [tools/Run-OneButtonValidate.ps1](./Run-OneButtonValidate.ps1) |
| `Run-OneShotBuildAndTests.ps1` | Requires -Version 7.0 | `MinimumSupportedLVVersion` (int), `PackageMinimumSupportedLVVersion` (int) | [tools/icon-editor/Run-OneShotBuildAndTests.ps1](./icon-editor/Run-OneShotBuildAndTests.ps1) |
| `Run-OneShotBuildAndTests.ps1` | Requires -Version 7.0 | `MinimumSupportedLVVersion` (int), `PackageMinimumSupportedLVVersion` (int) | [tools/icon-editor/Run-OneShotBuildAndTests.ps1](./icon-editor/Run-OneShotBuildAndTests.ps1) |
| `Run-Pester.ps1` | Ensure the required Pester version is available locally | — | [tools/Run-Pester.ps1](./Run-Pester.ps1) |
| `Run-SessionIndexValidation.ps1` | — | `ResultsPath` (string), `SchemaPath` (string) | [tools/Run-SessionIndexValidation.ps1](./Run-SessionIndexValidation.ps1) |
| `Run-StagedLVCompare.ps1` | Runs LVCompare against staged VI pairs recorded by Invoke-PRVIStaging. | — | [tools/Run-StagedLVCompare.ps1](./Run-StagedLVCompare.ps1) |
| `Run-VICompareSample.ps1` | Requires -Version 7.0 | `LabVIEWPath` (string), `BaseVI` (string), `HeadVI` (string), `OutputRoot` (string), `Label` (string), `DryRun` (switch) | [tools/Run-VICompareSample.ps1](./Run-VICompareSample.ps1) |
| `Run-ValidateContainer.ps1` | Requires -Version 7.0 | — | [tools/Run-ValidateContainer.ps1](./Run-ValidateContainer.ps1) |
| `RunnerInvoker.psm1` | Temporarily exclude node.exe from tracking to avoid conflating with runner internals | — | [tools/RunnerInvoker/RunnerInvoker.psm1](./RunnerInvoker/RunnerInvoker.psm1) |
| `RunnerInvoker.psm1` | Temporarily exclude node.exe from tracking to avoid conflating with runner internals | — | [tools/RunnerInvoker/RunnerInvoker.psm1](./RunnerInvoker/RunnerInvoker.psm1) |
| `RunnerProfile.psm1` | — | `ForceRefresh` (switch) | [tools/RunnerProfile.psm1](./RunnerProfile.psm1) |
| `Send-CtrlC.ps1` | Attempt to send Ctrl+C (and Ctrl+Break) to target console processes to unblock hangs. | — | [tools/Send-CtrlC.ps1](./Send-CtrlC.ps1) |
| `Session-Lock.ps1` | — | — | [tools/Session-Lock.ps1](./Session-Lock.ps1) |
| `Set-IntegrationEnv.Sample.ps1` | Sample script to set environment variables required for CompareVI integration tests. | `BaseVi` (string), `HeadVi` (string) | [tools/Set-IntegrationEnv.Sample.ps1](./Set-IntegrationEnv.Sample.ps1) |
| `Simulate-IconEditorBuild.ps1` | Requires -Version 7.0 | — | [tools/icon-editor/Simulate-IconEditorBuild.ps1](./icon-editor/Simulate-IconEditorBuild.ps1) |
| `Simulate-IconEditorBuild.ps1` | Requires -Version 7.0 | — | [tools/icon-editor/Simulate-IconEditorBuild.ps1](./icon-editor/Simulate-IconEditorBuild.ps1) |
| `Simulate-Release.ps1` | Requires -Version 7.0 | `Execute` (switch), `DryRun` (switch) | [tools/priority/Simulate-Release.ps1](./priority/Simulate-Release.ps1) |
| `Simulate-Release.ps1` | Requires -Version 7.0 | `Execute` (switch), `DryRun` (switch) | [tools/priority/Simulate-Release.ps1](./priority/Simulate-Release.ps1) |
| `Stage-BuildArtifacts.ps1` | Requires -Version 7.0 | — | [tools/icon-editor/Stage-BuildArtifacts.ps1](./icon-editor/Stage-BuildArtifacts.ps1) |
| `Stage-BuildArtifacts.ps1` | Requires -Version 7.0 | — | [tools/icon-editor/Stage-BuildArtifacts.ps1](./icon-editor/Stage-BuildArtifacts.ps1) |
| `Stage-CompareInputs.ps1` | Copy VI inputs into a temporary staging directory for safe LVCompare usage. | — | [tools/Stage-CompareInputs.ps1](./Stage-CompareInputs.ps1) |
| `Stage-IconEditorSnapshot.ps1` | Requires -Version 7.0 | — | [tools/icon-editor/Stage-IconEditorSnapshot.ps1](./icon-editor/Stage-IconEditorSnapshot.ps1) |
| `Stage-IconEditorSnapshot.ps1` | Requires -Version 7.0 | — | [tools/icon-editor/Stage-IconEditorSnapshot.ps1](./icon-editor/Stage-IconEditorSnapshot.ps1) |
| `Start-RunnerInvoker.ps1` | Default single-compare sessions to enable autostop unless explicitly disabled | — | [tools/RunnerInvoker/Start-RunnerInvoker.ps1](./RunnerInvoker/Start-RunnerInvoker.ps1) |
| `Start-RunnerInvoker.ps1` | Default single-compare sessions to enable autostop unless explicitly disabled | — | [tools/RunnerInvoker/Start-RunnerInvoker.ps1](./RunnerInvoker/Start-RunnerInvoker.ps1) |
| `Summarize-PRVIHistory.ps1` | Builds a Markdown summary from pr-vi-history-summary@v1 payloads. | — | [tools/Summarize-PRVIHistory.ps1](./Summarize-PRVIHistory.ps1) |
| `Summarize-PesterCategories.ps1` | Aggregate per-category Pester session-index totals and append a compact block to job summary. | — | [tools/Summarize-PesterCategories.ps1](./Summarize-PesterCategories.ps1) |
| `Summarize-VIStaging.ps1` | Produces human-friendly summaries for staged LVCompare results. | — | [tools/Summarize-VIStaging.ps1](./Summarize-VIStaging.ps1) |
| `Sync-IconEditorFork.ps1` | Requires -Version 7.0 | `RemoteName` (string), `RepoSlug` (string), `Branch` (string), `WorkingPath` (string), `UpdateFixture` (switch), `RunValidateLocal` (switch)… | [tools/icon-editor/Sync-IconEditorFork.ps1](./icon-editor/Sync-IconEditorFork.ps1) |
| `Sync-IconEditorFork.ps1` | Requires -Version 7.0 | `RemoteName` (string), `RepoSlug` (string), `Branch` (string), `WorkingPath` (string), `UpdateFixture` (switch), `RunValidateLocal` (switch)… | [tools/icon-editor/Sync-IconEditorFork.ps1](./icon-editor/Sync-IconEditorFork.ps1) |
| `Tail-Snapshots.ps1` | Follow a metrics snapshots NDJSON file produced by -MetricsSnapshotPath and pretty-print selected fields. | — | [tools/Tail-Snapshots.ps1](./Tail-Snapshots.ps1) |
| `Test-DevModeStability.ps1` | Requires -Version 7.0 | `LabVIEWVersion` (int) | [tools/icon-editor/Test-DevModeStability.ps1](./icon-editor/Test-DevModeStability.ps1) |
| `Test-DevModeStability.ps1` | Requires -Version 7.0 | `LabVIEWVersion` (int) | [tools/icon-editor/Test-DevModeStability.ps1](./icon-editor/Test-DevModeStability.ps1) |
| `Test-FixtureValidationDeltaSchema.ps1` | Lightweight validation (no external JSON Schema engine): assert required keys & types | — | [tools/Test-FixtureValidationDeltaSchema.ps1](./Test-FixtureValidationDeltaSchema.ps1) |
| `Test-ForkSimulation.ps1` | Creates a fork-style pull request, runs the compare workflows, and optionally | `BaseBranch` (string), `KeepBranch` (switch), `DryRun` (switch) | [tools/Test-ForkSimulation.ps1](./Test-ForkSimulation.ps1) |
| `Test-IconEditorPackage.ps1` | Requires -Version 7.0 | `VipPath` (string[]), `ManifestPath` (string), `ResultsRoot` (string), `VersionInfo` (hashtable), `RequireVip` (switch) | [tools/icon-editor/Test-IconEditorPackage.ps1](./icon-editor/Test-IconEditorPackage.ps1) |
| `Test-IconEditorPackage.ps1` | Requires -Version 7.0 | `VipPath` (string[]), `ManifestPath` (string), `ResultsRoot` (string), `VersionInfo` (hashtable), `RequireVip` (switch) | [tools/icon-editor/Test-IconEditorPackage.ps1](./icon-editor/Test-IconEditorPackage.ps1) |
| `Test-PRVIHistorySmoke.ps1` | End-to-end smoke test for the PR VI history workflow. | `BaseBranch` (string), `KeepBranch` (switch), `DryRun` (switch) | [tools/Test-PRVIHistorySmoke.ps1](./Test-PRVIHistorySmoke.ps1) |
| `Test-PRVIStagingSmoke.ps1` | End-to-end smoke test for the PR VI staging workflow. | `BaseBranch` (string), `KeepBranch` (switch), `DryRun` (switch) | [tools/Test-PRVIStagingSmoke.ps1](./Test-PRVIStagingSmoke.ps1) |
| `Test-ProviderTelemetry.ps1` | Validates VIPM provider comparison telemetry. | `InputPath` (string), `AllowStatuses` (string[]) | [tools/Vipm/Test-ProviderTelemetry.ps1](./Vipm/Test-ProviderTelemetry.ps1) |
| `Test-ProviderTelemetry.ps1` | Validates VIPM provider comparison telemetry. | `InputPath` (string), `AllowStatuses` (string[]) | [tools/Vipm/Test-ProviderTelemetry.ps1](./Vipm/Test-ProviderTelemetry.ps1) |
| `TestSelection.psm1` | — | — | [tools/Dispatcher/TestSelection.psm1](./Dispatcher/TestSelection.psm1) |
| `TestSelection.psm1` | — | — | [tools/Dispatcher/TestSelection.psm1](./Dispatcher/TestSelection.psm1) |
| `TestStand-CompareHarness.ps1` | Thin wrapper for TestStand: warmup LabVIEW runtime, run LVCompare, and optionally close. | — | [tools/TestStand-CompareHarness.ps1](./TestStand-CompareHarness.ps1) |
| `Tick.psm1` | — | `TickMilliseconds` (int) | [tools/Timing/Tick.psm1](./Timing/Tick.psm1) |
| `Tick.psm1` | — | `TickMilliseconds` (int) | [tools/Timing/Tick.psm1](./Timing/Tick.psm1) |
| `Traceability-Matrix.ps1` | Traceability Matrix Builder (Traceability Matrix Plan v1.0.0) | `TestsPath` (string), `ResultsRoot` (string), `OutDir` (string), `IncludePatterns` (string[]), `RunId` (string), `Seed` (string)… | [tools/Traceability-Matrix.ps1](./Traceability-Matrix.ps1) |
| `Track-WorkflowRun.ps1` | Monitor a GitHub Actions workflow run and display per-job status in real time. | — | [tools/Track-WorkflowRun.ps1](./Track-WorkflowRun.ps1) |
| `Trigger-StandingWorkflow.ps1` | Requires -Version 7.0 | `PlanOnly` (switch), `Force` (switch), `RepositoryRoot` (string) | [tools/Trigger-StandingWorkflow.ps1](./Trigger-StandingWorkflow.ps1) |
| `Update-FixtureManifest.ps1` | Updates fixtures.manifest.json with current SHA256 & size metadata and optional pair digest block. | — | [tools/Update-FixtureManifest.ps1](./Update-FixtureManifest.ps1) |
| `Update-IconEditorFixtureReport.ps1` | Requires -Version 7.0 | `FixturePath` (string), `ManifestPath` (string), `ResultsRoot` (string), `ResourceOverlayRoot` (string), `SkipDocUpdate` (switch) | [tools/icon-editor/Update-IconEditorFixtureReport.ps1](./icon-editor/Update-IconEditorFixtureReport.ps1) |
| `Update-IconEditorFixtureReport.ps1` | Requires -Version 7.0 | `FixturePath` (string), `ManifestPath` (string), `ResultsRoot` (string), `ResourceOverlayRoot` (string), `SkipDocUpdate` (switch) | [tools/icon-editor/Update-IconEditorFixtureReport.ps1](./icon-editor/Update-IconEditorFixtureReport.ps1) |
| `Update-SessionIndexBranchProtection.ps1` | Inject branch-protection verification metadata into a session-index.json file. | `ResultsDir` (string), `PolicyPath` (string), `ProducedContexts` (string[]), `Branch` (string), `Strict` (switch), `ActualContexts` (string[]) | [tools/Update-SessionIndexBranchProtection.ps1](./Update-SessionIndexBranchProtection.ps1) |
| `Update-SessionIndexWatcher.ps1` | — | `ResultsDir` (string), `WatcherJson` (string) | [tools/Update-SessionIndexWatcher.ps1](./Update-SessionIndexWatcher.ps1) |
| `VICategoryBuckets.psm1` | Requires -Version 7.0 | `Name` (string) | [tools/VICategoryBuckets.psm1](./VICategoryBuckets.psm1) |
| `Validate-AdrLinks.ps1` | — | `RequirementsDir` (string), `AdrDir` (string) | [tools/Validate-AdrLinks.ps1](./Validate-AdrLinks.ps1) |
| `Validate-Fixtures.ps1` | Validates canonical fixture VIs (Phase 1 + Phase 2 hash manifest, refined schema & JSON support). | `Json`, `TestAllowFixtureUpdate` | [tools/Validate-Fixtures.ps1](./Validate-Fixtures.ps1) |
| `VendorTools.psm1` | Requires -Version 7.0 | `StartPath` (string) | [tools/VendorTools.psm1](./VendorTools.psm1) |
| `Verify-FixtureCompare.ps1` | Do not re-run compare; use existing exec JSON (copy when different path) | — | [tools/Verify-FixtureCompare.ps1](./Verify-FixtureCompare.ps1) |
| `Verify-LVCompareSetup.ps1` | Requires -Version 7.0 | `ProbeCli` (switch) | [tools/Verify-LVCompareSetup.ps1](./Verify-LVCompareSetup.ps1) |
| `Verify-LocalDiffSession.ps1` | Requires -Version 7.0 | — | [tools/Verify-LocalDiffSession.ps1](./Verify-LocalDiffSession.ps1) |
| `Vipm.psm1` | Requires -Version 7.0 | — | [tools/Vipm.psm1](./Vipm.psm1) |
| `VipmBuildHelpers.psm1` | Requires -Version 7.0 | — | [tools/icon-editor/VipmBuildHelpers.psm1](./icon-editor/VipmBuildHelpers.psm1) |
| `VipmBuildHelpers.psm1` | Requires -Version 7.0 | — | [tools/icon-editor/VipmBuildHelpers.psm1](./icon-editor/VipmBuildHelpers.psm1) |
| `VipmDependencyHelpers.psm1` | Requires -Version 7.0 | — | [tools/icon-editor/VipmDependencyHelpers.psm1](./icon-editor/VipmDependencyHelpers.psm1) |
| `VipmDependencyHelpers.psm1` | Requires -Version 7.0 | — | [tools/icon-editor/VipmDependencyHelpers.psm1](./icon-editor/VipmDependencyHelpers.psm1) |
| `Wait-InvokerReady.ps1` | Requires -Version 7.0 | — | [tools/RunnerInvoker/Wait-InvokerReady.ps1](./RunnerInvoker/Wait-InvokerReady.ps1) |
| `Wait-InvokerReady.ps1` | Requires -Version 7.0 | — | [tools/RunnerInvoker/Wait-InvokerReady.ps1](./RunnerInvoker/Wait-InvokerReady.ps1) |
| `Warmup-LabVIEW.ps1` | Compatibility wrapper for Warmup-LabVIEWRuntime.ps1 (deprecated entry point). | `LabVIEWPath` (string), `MinimumSupportedLVVersion` (string), `SupportedBitness` (string), `TimeoutSeconds` (int), `IdleWaitSeconds` (int), `JsonLogPath` (string)… | [tools/Warmup-LabVIEW.ps1](./Warmup-LabVIEW.ps1) |
| `Warmup-LabVIEWRuntime.ps1` | Deterministic LabVIEW runtime warmup for self-hosted Windows runners. | `StopAfterWarmup` | [tools/Warmup-LabVIEWRuntime.ps1](./Warmup-LabVIEWRuntime.ps1) |
| `Watch-OrchestratedRest.ps1` | Wrapper for the REST watcher that writes watcher-rest.json and merges it into session-index.json. | `RunId` (int), `Branch` (string), `Workflow` (string), `PollMs` (int), `ErrorGraceMs` (int), `NotFoundGraceMs` (int)… | [tools/Watch-OrchestratedRest.ps1](./Watch-OrchestratedRest.ps1) |
| `Watch-Pester.ps1` | Lightweight session naming for observability | `Path` (string), `Filter` (string), `DebounceMilliseconds` (int), `RunAllOnStart` (switch), `NoSummary` (switch), `TestPath` (string)… | [tools/Watch-Pester.ps1](./Watch-Pester.ps1) |
| `Watch-RunAndTrack.ps1` | Dispatch a GitHub workflow and monitor its jobs until completion. | `Workflow` (string), `Ref` (string), `Repo` (string), `PollSeconds` (int), `MonitorPollSeconds` (int), `TimeoutSeconds` (int)… | [tools/Watch-RunAndTrack.ps1](./Watch-RunAndTrack.ps1) |
| `Write-AgentContext.ps1` | Repo context | `ResultsDir` (string), `MaxNotices` (int), `AppendToStepSummary` (switch), `Quiet` (switch) | [tools/Write-AgentContext.ps1](./Write-AgentContext.ps1) |
| `Write-ArtifactList.ps1` | Append a compact artifact path list to the job summary. | — | [tools/Write-ArtifactList.ps1](./Write-ArtifactList.ps1) |
| `Write-ArtifactMap.ps1` | Append a detailed artifact map (exists, size, modified) to job summary. | `Paths` (string[]), `PathsList` (string), `Title` (string) | [tools/Write-ArtifactMap.ps1](./Write-ArtifactMap.ps1) |
| `Write-CompareSummaryBlock.ps1` | Append a concise Compare VI block from compare-summary.json. | `Path` (string), `Title` (string) | [tools/Write-CompareSummaryBlock.ps1](./Write-CompareSummaryBlock.ps1) |
| `Write-DerivedEnv.ps1` | — | — | [tools/Write-DerivedEnv.ps1](./Write-DerivedEnv.ps1) |
| `Write-DeterminismSummary.ps1` | Append a concise Determinism block to the job summary based on LOOP_* envs. | — | [tools/Write-DeterminismSummary.ps1](./Write-DeterminismSummary.ps1) |
| `Write-FixtureDriftSummary.ps1` | Append a concise Fixture Drift block from drift-summary.json (best-effort). | `Dir` (string), `SummaryFile` (string) | [tools/Write-FixtureDriftSummary.ps1](./Write-FixtureDriftSummary.ps1) |
| `Write-FixtureValidationSummary.ps1` | — | — | [tools/Write-FixtureValidationSummary.ps1](./Write-FixtureValidationSummary.ps1) |
| `Write-InteractivityProbe.ps1` | Emit a small interactivity/console probe to the job Step Summary and stdout. | — | [tools/Write-InteractivityProbe.ps1](./Write-InteractivityProbe.ps1) |
| `Write-PesterTopFailures.ps1` | Append a concise “Top Failures” section to the job summary from Pester outputs. | `ResultsDir` (string), `Top` (int) | [tools/Write-PesterTopFailures.ps1](./Write-PesterTopFailures.ps1) |
| `Write-RerunHint.ps1` | Append a concise re-run hint block using gh workflow run with sample_id. | — | [tools/Write-RerunHint.ps1](./Write-RerunHint.ps1) |
| `Write-RerunSummary.ps1` | Append a step summary block that captures a rerun command and workflow link. | — | [tools/Write-RerunSummary.ps1](./Write-RerunSummary.ps1) |
| `Write-RunProvenance.ps1` | Write run provenance (with fallbacks) to results/provenance.json and optionally append to the job summary. | `ResultsDir` (string), `FileName` (string), `AppendStepSummary` (switch) | [tools/Write-RunProvenance.ps1](./Write-RunProvenance.ps1) |
| `Write-RunReport.ps1` | Requires -Version 7.0 | — | [tools/report/Write-RunReport.ps1](./report/Write-RunReport.ps1) |
| `Write-RunReport.ps1` | Requires -Version 7.0 | — | [tools/report/Write-RunReport.ps1](./report/Write-RunReport.ps1) |
| `Write-RunnerIdentity.ps1` | Append runner identity metadata to job summary. | `SampleId` (string) | [tools/Write-RunnerIdentity.ps1](./Write-RunnerIdentity.ps1) |
| `Write-SessionIndexSummary.ps1` | Append a concise Session block from tests/results/session-index.json. | `ResultsDir` (string), `FileName` (string) | [tools/Write-SessionIndexSummary.ps1](./Write-SessionIndexSummary.ps1) |
| `bootstrap.ps1` | Requires -Version 7.0 | `VerboseHooks` (switch), `PreflightOnly` (switch) | [tools/priority/bootstrap.ps1](./priority/bootstrap.ps1) |
| `bootstrap.ps1` | Requires -Version 7.0 | `VerboseHooks` (switch), `PreflightOnly` (switch) | [tools/priority/bootstrap.ps1](./priority/bootstrap.ps1) |
| `dl-actionlint.sh` | !/bin/bash | — | [tools/dl-actionlint.sh](./dl-actionlint.sh) |
| `gcli.Provider.psd1` | Module manifest for module 'gcli.Provider' | — | [tools/providers/gcli/gcli.Provider.psd1](./providers/gcli/gcli.Provider.psd1) |
| `gcli.Provider.psd1` | Module manifest for module 'gcli.Provider' | — | [tools/providers/gcli/gcli.Provider.psd1](./providers/gcli/gcli.Provider.psd1) |
| `gcli.Provider.psd1` | Module manifest for module 'gcli.Provider' | — | [tools/providers/gcli/gcli.Provider.psd1](./providers/gcli/gcli.Provider.psd1) |
| `labviewcli.Provider.psd1` | Module manifest for module 'labviewcli.Provider' | — | [tools/providers/labviewcli/labviewcli.Provider.psd1](./providers/labviewcli/labviewcli.Provider.psd1) |
| `labviewcli.Provider.psd1` | Module manifest for module 'labviewcli.Provider' | — | [tools/providers/labviewcli/labviewcli.Provider.psd1](./providers/labviewcli/labviewcli.Provider.psd1) |
| `labviewcli.Provider.psd1` | Module manifest for module 'labviewcli.Provider' | — | [tools/providers/labviewcli/labviewcli.Provider.psd1](./providers/labviewcli/labviewcli.Provider.psd1) |
| `pre-commit.ps1` | Requires -Version 7.0 | `StagedFiles` (string[]) | [tools/hooks/scripts/pre-commit.ps1](./hooks/scripts/pre-commit.ps1) |
| `pre-commit.ps1` | Requires -Version 7.0 | `StagedFiles` (string[]) | [tools/hooks/scripts/pre-commit.ps1](./hooks/scripts/pre-commit.ps1) |
| `pre-commit.ps1` | Requires -Version 7.0 | `StagedFiles` (string[]) | [tools/hooks/scripts/pre-commit.ps1](./hooks/scripts/pre-commit.ps1) |
| `pre-commit.ps1` | Requires -Version 7.0 | — | [tools/hooks/pre-commit.ps1](./hooks/pre-commit.ps1) |
| `pre-commit.ps1` | Requires -Version 7.0 | — | [tools/hooks/pre-commit.ps1](./hooks/pre-commit.ps1) |
| `pre-push.ps1` | Requires -Version 7.0 | — | [tools/hooks/pre-push.ps1](./hooks/pre-push.ps1) |
| `pre-push.ps1` | Requires -Version 7.0 | — | [tools/hooks/pre-push.ps1](./hooks/pre-push.ps1) |
| `pre-push.ps1` | Requires -Version 7.0 | — | [tools/hooks/scripts/pre-push.ps1](./hooks/scripts/pre-push.ps1) |
| `pre-push.ps1` | Requires -Version 7.0 | — | [tools/hooks/scripts/pre-push.ps1](./hooks/scripts/pre-push.ps1) |
| `pre-push.ps1` | Requires -Version 7.0 | — | [tools/hooks/scripts/pre-push.ps1](./hooks/scripts/pre-push.ps1) |
| `render-ci-composite.ps1` | Requires -Version 7.0 | `RenderVendor` (switch) | [tools/workflows/render-ci-composite.ps1](./workflows/render-ci-composite.ps1) |
| `render-ci-composite.ps1` | Requires -Version 7.0 | `RenderVendor` (switch) | [tools/workflows/render-ci-composite.ps1](./workflows/render-ci-composite.ps1) |
| `update_workflows.py` | !/usr/bin/env python3 | — | [tools/workflows/update_workflows.py](./workflows/update_workflows.py) |
| `update_workflows.py` | !/usr/bin/env python3 | — | [tools/workflows/update_workflows.py](./workflows/update_workflows.py) |
| `vipm-gcli.Provider.psd1` | — | — | [tools/providers/vipm-gcli/vipm-gcli.Provider.psd1](./providers/vipm-gcli/vipm-gcli.Provider.psd1) |
| `vipm-gcli.Provider.psd1` | — | — | [tools/providers/vipm-gcli/vipm-gcli.Provider.psd1](./providers/vipm-gcli/vipm-gcli.Provider.psd1) |
| `vipm-gcli.Provider.psd1` | — | — | [tools/providers/vipm-gcli/vipm-gcli.Provider.psd1](./providers/vipm-gcli/vipm-gcli.Provider.psd1) |
| `vipm.Provider.psd1` | Module manifest for module 'vipm.Provider' | — | [tools/providers/vipm/vipm.Provider.psd1](./providers/vipm/vipm.Provider.psd1) |
| `vipm.Provider.psd1` | Module manifest for module 'vipm.Provider' | — | [tools/providers/vipm/vipm.Provider.psd1](./providers/vipm/vipm.Provider.psd1) |
| `vipm.Provider.psd1` | Module manifest for module 'vipm.Provider' | — | [tools/providers/vipm/vipm.Provider.psd1](./providers/vipm/vipm.Provider.psd1) |

## Usage Notes
- Run scripts from repo root unless noted.
- PowerShell: `pwsh` or `powershell` recommended; execution policy may need `RemoteSigned`.
- Linux/macOS: ensure `chmod +x` for shell scripts.
- For reproducibility, pin LabVIEW/VIPM versions and set environment (see `docs/LABVIEW_GATING.md` if present).

## Cross-links
- Requirements: `docs/requirements/Icon-Editor-Lab_SRS.md` (if present)
- RTM: `docs/requirements/Icon-Editor-Lab_RTM.csv` (if present)
- Test docs: `docs/testing/` (if present)

> Regenerate this file by re-running the doc generator in CI to keep in sync with tool headers.





