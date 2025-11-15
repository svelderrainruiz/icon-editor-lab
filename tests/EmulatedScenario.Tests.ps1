#Requires -Version 7.0
#Requires -Modules Pester

param()

Describe 'Emulated end-to-end scenarios' -Tag 'Emulated','DevMode','MIP','LUnit','LVCompare' {
  BeforeAll {
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:runner   = Join-Path $script:repoRoot 'tests/tools/Run-EmulatedScenario.ps1'
    Test-Path -LiteralPath $script:runner | Should -BeTrue

    $mipHelpersPath = Join-Path $script:repoRoot 'src/tools/icon-editor/MipScenarioHelpers.psm1'
    Import-Module $mipHelpersPath -Force
  }

  It 'produces a happy-path emulated run' {
    $env:WORKSPACE_ROOT = $script:repoRoot

    pwsh -NoLogo -NoProfile -File $script:runner -ScenarioFamily 'e2e.happy' | Out-Null

    $resultsRoot  = Join-Path $script:repoRoot 'tests/results'
    $agentRoot    = Join-Path $resultsRoot '_agent'
    $iconAgent    = Join-Path $agentRoot 'icon-editor'

    # MIP report
    $mipDir = Join-Path $agentRoot 'reports/missing-in-project'
    Test-Path -LiteralPath $mipDir | Should -BeTrue
    $mipReport = Get-ChildItem -LiteralPath $mipDir -Filter 'mip-emulated-*.json' | Sort-Object LastWriteTime | Select-Object -Last 1
    $mipReport | Should -Not -BeNullOrEmpty
    $mipPayload = Get-Content -LiteralPath $mipReport.FullName -Raw | ConvertFrom-Json
    $mipPayload.kind | Should -Be 'missing-in-project'
    (Get-MissingInProjectMissingViPaths -ReportPath $mipReport.FullName).Count | Should -Be 0

    # LVCompare report
    $lvDir = Join-Path $agentRoot 'reports/lvcompare'
    Test-Path -LiteralPath $lvDir | Should -BeTrue
    $lvReport = Get-ChildItem -LiteralPath $lvDir -Filter 'lvcompare-emulated-*.json' | Sort-Object LastWriteTime | Select-Object -Last 1
    $lvReport | Should -Not -BeNullOrEmpty
    $lvPayload = Get-Content -LiteralPath $lvReport.FullName -Raw | ConvertFrom-Json
    $lvPayload.kind | Should -Be 'lvcompare'
    $lvPayload.extra.htmlReportPath | Should -Not -BeNullOrEmpty

    # LUnit report
    $unitDir = Join-Path $agentRoot 'reports/unit-tests'
    Test-Path -LiteralPath $unitDir | Should -BeTrue
    $unitReport = Get-ChildItem -LiteralPath $unitDir -Filter 'unit-tests-emulated-*.json' | Sort-Object LastWriteTime | Select-Object -Last 1
    $unitReport | Should -Not -BeNullOrEmpty
    $unitPayload = Get-Content -LiteralPath $unitReport.FullName -Raw | ConvertFrom-Json
    $unitPayload.kind | Should -Be 'unit-tests'
    $unitPayload.extra.failedTests.Count | Should -Be 0
    # VI Analyzer run via LabVIEWCLI (emulated)
    $anRoot = Join-Path $agentRoot 'vi-analyzer'
    Test-Path -LiteralPath $anRoot | Should -BeTrue
    $anRun = Get-ChildItem -LiteralPath $anRoot -Directory -Filter 'vi-analyzer-emulated-*' | Sort-Object LastWriteTime | Select-Object -Last 1
    $anRun | Should -Not -BeNullOrEmpty
    $anPayload = Get-Content -LiteralPath (Join-Path $anRun.FullName 'vi-analyzer.json') -Raw | ConvertFrom-Json
    $anPayload.schema   | Should -Be 'icon-editor/vi-analyzer@v1'
    $anPayload.tool     | Should -Be 'LabVIEWCLI'
    $anPayload.exitCode | Should -Be 0
  }

  It 'produces a failure run with MIP ok and LUnit failures' {
    $env:WORKSPACE_ROOT = $script:repoRoot

    pwsh -NoLogo -NoProfile -File $script:runner -ScenarioFamily 'e2e.mip-lunit-fail' | Out-Null

    $resultsRoot  = Join-Path $script:repoRoot 'tests/results'
    $agentRoot    = Join-Path $resultsRoot '_agent'
    $iconAgent    = Join-Path $agentRoot 'icon-editor'

    # MIP report should not report missing VIs
    $mipDir = Join-Path $agentRoot 'reports/missing-in-project'
    $mipReport = Get-ChildItem -LiteralPath $mipDir -Filter 'mip-emulated-*.json' | Sort-Object LastWriteTime | Select-Object -Last 1
    $mipPayload = Get-Content -LiteralPath $mipReport.FullName -Raw | ConvertFrom-Json
    (Get-MissingInProjectMissingViPaths -ReportPath $mipReport.FullName).Count | Should -Be 0

    # LUnit report should have failed tests populated
    $unitDir = Join-Path $agentRoot 'reports/unit-tests'
    $unitReport = Get-ChildItem -LiteralPath $unitDir -Filter 'unit-tests-emulated-*.json' | Sort-Object LastWriteTime | Select-Object -Last 1
    $unitPayload = Get-Content -LiteralPath $unitReport.FullName -Raw | ConvertFrom-Json
    $unitPayload.extra.failedTests.Count | Should -BeGreaterThan 0

    # VI Analyzer should still be present and indicate success
    $anRoot = Join-Path $agentRoot 'vi-analyzer'
    $anRun = Get-ChildItem -LiteralPath $anRoot -Directory -Filter 'vi-analyzer-emulated-*' | Sort-Object LastWriteTime | Select-Object -Last 1
    $anPayload = Get-Content -LiteralPath (Join-Path $anRun.FullName 'vi-analyzer.json') -Raw | ConvertFrom-Json
    $anPayload.exitCode | Should -Be 0
  }

  It 'produces a run with MIP missing VIs and LVCompare capture missing' {
    $env:WORKSPACE_ROOT = $script:repoRoot

    pwsh -NoLogo -NoProfile -File $script:runner -ScenarioFamily 'e2e.mip-missing-vis+lvcompare-missing' | Out-Null

    $resultsRoot  = Join-Path $script:repoRoot 'tests/results'
    $agentRoot    = Join-Path $resultsRoot '_agent'
    $iconAgent    = Join-Path $agentRoot 'icon-editor'

    # MIP report should list missing VIs
    $mipDir = Join-Path $agentRoot 'reports/missing-in-project'
    $mipReport = Get-ChildItem -LiteralPath $mipDir -Filter 'mip-emulated-*.json' | Sort-Object LastWriteTime | Select-Object -Last 1
    $missing = Get-MissingInProjectMissingViPaths -ReportPath $mipReport.FullName
    $missing.Count | Should -Be 2

    # LVCompare report should have missing capture
    $lvDir = Join-Path $agentRoot 'reports/lvcompare'
    $lvReport = Get-ChildItem -LiteralPath $lvDir -Filter 'lvcompare-emulated-*.json' | Sort-Object LastWriteTime | Select-Object -Last 1
    $lvPayload = Get-Content -LiteralPath $lvReport.FullName -Raw | ConvertFrom-Json
    $lvPayload.extra.capturePath | Should -BeNullOrEmpty

    # VI Analyzer run should indicate dev-mode drift (exitCode non-zero, devModeLikelyDisabled=true)
    $anRoot = Join-Path $agentRoot 'vi-analyzer'
    $anRun = Get-ChildItem -LiteralPath $anRoot -Directory -Filter 'vi-analyzer-emulated-*' | Sort-Object LastWriteTime | Select-Object -Last 1
    $anPayload = Get-Content -LiteralPath (Join-Path $anRun.FullName 'vi-analyzer.json') -Raw | ConvertFrom-Json
    $anPayload.exitCode              | Should -Not -Be 0
    $anPayload.devModeLikelyDisabled | Should -BeTrue

    # LUnit report should indicate all tests passed for this scenario
    $unitDir = Join-Path $agentRoot 'reports/unit-tests'
    Test-Path -LiteralPath $unitDir | Should -BeTrue
    $unitReport = Get-ChildItem -LiteralPath $unitDir -Filter 'unit-tests-emulated-*.json' | Sort-Object LastWriteTime | Select-Object -Last 1
    $unitReport | Should -Not -BeNullOrEmpty
    $unitPayload = Get-Content -LiteralPath $unitReport.FullName -Raw | ConvertFrom-Json
    $unitPayload.kind | Should -Be 'unit-tests'
    $unitPayload.extra.failedTests.Count | Should -Be 0
  }

  It 'produces a VI Package build telemetry record for vipm-build scenario' {
    $env:WORKSPACE_ROOT = $script:repoRoot

    pwsh -NoLogo -NoProfile -File $script:runner -ScenarioFamily 'e2e.vipm-build' | Out-Null

    $resultsRoot = Join-Path $script:repoRoot 'tests/results'
    $vipmRoot    = Join-Path $resultsRoot '_agent/icon-editor/vipm-cli-build'
    Test-Path -LiteralPath $vipmRoot | Should -BeTrue

    $vipmTelemetry = Get-ChildItem -LiteralPath $vipmRoot -Filter 'vipm-package-*.json' | Sort-Object LastWriteTime | Select-Object -Last 1
    $vipmTelemetry | Should -Not -BeNullOrEmpty

    $payload = Get-Content -LiteralPath $vipmTelemetry.FullName -Raw | ConvertFrom-Json
    $payload.schema        | Should -Be 'icon-editor/vipm-package@v1'
    $payload.toolchain     | Should -Be 'vipm'
    $payload.provider      | Should -Be 'vipm-emulated'
    $payload.artifactCount | Should -BeGreaterThan 0
    $payload.artifacts[0].Name | Should -Match '\.vip$'
  }

  It 'produces VIPM telemetry with zero artifacts for vipm-build-no-artifacts' {
    $env:WORKSPACE_ROOT = $script:repoRoot

    pwsh -NoLogo -NoProfile -File $script:runner -ScenarioFamily 'e2e.vipm-build-no-artifacts' | Out-Null

    $resultsRoot = Join-Path $script:repoRoot 'tests/results'
    $vipmRoot    = Join-Path $resultsRoot '_agent/icon-editor/vipm-cli-build'
    Test-Path -LiteralPath $vipmRoot | Should -BeTrue

    $vipmTelemetry = Get-ChildItem -LiteralPath $vipmRoot -Filter 'vipm-package-*.json'
    $vipmTelemetry | Should -Not -BeNullOrEmpty

    $payload = $null
    foreach ($file in $vipmTelemetry) {
      $candidate = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
      if ($candidate.metadata -and $candidate.metadata.scenarioKind -eq 'vipm.no-artifacts') {
        $payload = $candidate
        break
      }
    }

    $payload | Should -Not -BeNullOrEmpty
    $payload.schema        | Should -Be 'icon-editor/vipm-package@v1'
    $payload.artifactCount | Should -Be 0
  }

  It 'marks VIPM telemetry as display-only for vipm-build-display-only' {
    $env:WORKSPACE_ROOT = $script:repoRoot

    pwsh -NoLogo -NoProfile -File $script:runner -ScenarioFamily 'e2e.vipm-build-display-only' | Out-Null

    $resultsRoot = Join-Path $script:repoRoot 'tests/results'
    $vipmRoot    = Join-Path $resultsRoot '_agent/icon-editor/vipm-cli-build'
    Test-Path -LiteralPath $vipmRoot | Should -BeTrue

    $vipmTelemetry = Get-ChildItem -LiteralPath $vipmRoot -Filter 'vipm-package-*.json'
    $vipmTelemetry | Should -Not -BeNullOrEmpty

    $payload = $null
    foreach ($file in $vipmTelemetry) {
      $candidate = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
      if ($candidate.metadata -and $candidate.metadata.scenarioKind -eq 'vipm.display-only') {
        $payload = $candidate
        break
      }
    }

    $payload | Should -Not -BeNullOrEmpty
    $payload.schema      | Should -Be 'icon-editor/vipm-package@v1'
    $payload.displayOnly | Should -BeTrue
  }

  It 'produces a VI Package build telemetry record for vipb-gcli scenario' {
    $env:WORKSPACE_ROOT = $script:repoRoot

    pwsh -NoLogo -NoProfile -File $script:runner -ScenarioFamily 'e2e.vipb-gcli-build' | Out-Null

    $resultsRoot = Join-Path $script:repoRoot 'tests/results'
    $vipmRoot    = Join-Path $resultsRoot '_agent/icon-editor/vipm-cli-build'
    Test-Path -LiteralPath $vipmRoot | Should -BeTrue

    $vipmTelemetry = Get-ChildItem -LiteralPath $vipmRoot -Filter 'vipm-package-*.json'
    $vipmTelemetry | Should -Not -BeNullOrEmpty

    $payload = $null
    foreach ($file in $vipmTelemetry) {
      $candidate = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
      if ($candidate.metadata -and $candidate.metadata.scenarioFamily -eq 'e2e.vipb-gcli-build') {
        $payload = $candidate
        break
      }
    }

    $payload | Should -Not -BeNullOrEmpty
    $payload.schema    | Should -Be 'icon-editor/vipm-package@v1'
    $payload.toolchain | Should -Be 'vipb-gcli'
    $payload.provider  | Should -Be 'vipb-gcli-emulated'
  }
}
