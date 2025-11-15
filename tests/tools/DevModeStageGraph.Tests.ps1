#Requires -Version 7.0
#Requires -Modules Pester

param()

Describe 'DevMode stage graph summary' -Tag 'DevMode','StageGraph' {
  It 'treats a complete ordered graph as expected' {
    $repoRoot = Join-Path $TestDrive 'stagegraph-complete'
    New-Item -ItemType Directory -Path $repoRoot -Force | Out-Null

    $telemetryDir = Join-Path $repoRoot 'tests/results/_agent/icon-editor/dev-mode-run'
    New-Item -ItemType Directory -Path $telemetryDir -Force | Out-Null

    $run = [pscustomobject]@{
      runId     = 'run-complete-1'
      mode      = 'enable'
      operation = 'BuildPackage'
      stages    = @(
        [pscustomobject]@{ name = 'rogue-check';              durationSeconds = 0.1; status = 'ok' },
        [pscustomobject]@{ name = 'enable-addtoken-2025-64';  durationSeconds = 1.0; status = 'ok' },
        [pscustomobject]@{ name = 'enable-prepare-2025-64';   durationSeconds = 2.0; status = 'ok' }
      )
    }

    $run | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $telemetryDir 'dev-mode-run-1.json') -Encoding utf8

    $env:WORKSPACE_ROOT = $repoRoot

    $script = Join-Path $PSScriptRoot 'Summarize-DevModeStageGraph.ps1'
    pwsh -NoLogo -NoProfile -File $script | Out-Null

    $summaryPath = Join-Path $repoRoot 'tests/results/_agent/icon-editor/dev-mode-stage-graph-summary.json'
    Test-Path -LiteralPath $summaryPath | Should -BeTrue

    $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json

    $summary.TotalRuns       | Should -Be 1
    $summary.ExpectedGraphs  | Should -Be 1
    $summary.UnexpectedGraphs | Should -Be 0

    $runSummary = $summary.Runs[0]
    $runSummary.RunId | Should -Be 'run-complete-1'
    $runSummary.IsExpectedGraph | Should -BeTrue
    $runSummary.Anomalies.Count | Should -Be 0
  }

  It 'flags missing stages for enable runs' {
    $repoRoot = Join-Path $TestDrive 'stagegraph-missing'
    New-Item -ItemType Directory -Path $repoRoot -Force | Out-Null

    $telemetryDir = Join-Path $repoRoot 'tests/results/_agent/icon-editor/dev-mode-run'
    New-Item -ItemType Directory -Path $telemetryDir -Force | Out-Null

    $run = [pscustomobject]@{
      runId     = 'run-missing-1'
      mode      = 'enable'
      operation = 'BuildPackage'
      stages    = @(
        [pscustomobject]@{ name = 'enable-addtoken-2025-64'; durationSeconds = 1.0; status = 'ok' }
      )
    }

    $run | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $telemetryDir 'dev-mode-run-1.json') -Encoding utf8

    $env:WORKSPACE_ROOT = $repoRoot

    $script = Join-Path $PSScriptRoot 'Summarize-DevModeStageGraph.ps1'
    pwsh -NoLogo -NoProfile -File $script | Out-Null

    $summaryPath = Join-Path $repoRoot 'tests/results/_agent/icon-editor/dev-mode-stage-graph-summary.json'
    Test-Path -LiteralPath $summaryPath | Should -BeTrue

    $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json

    $summary.TotalRuns       | Should -Be 1
    $summary.ExpectedGraphs  | Should -Be 0
    $summary.UnexpectedGraphs | Should -Be 1

    $runSummary = $summary.Runs[0]
    $runSummary.IsExpectedGraph | Should -BeFalse
    $runSummary.Anomalies | Should -Contain 'missing-enable-prepare'
    $runSummary.Anomalies | Should -Not -Contain 'missing-enable-addtoken'
  }

  It 'flags out-of-order and duplicate stages' {
    $repoRoot = Join-Path $TestDrive 'stagegraph-anomalies'
    New-Item -ItemType Directory -Path $repoRoot -Force | Out-Null

    $telemetryDir = Join-Path $repoRoot 'tests/results/_agent/icon-editor/dev-mode-run'
    New-Item -ItemType Directory -Path $telemetryDir -Force | Out-Null

    $run = [pscustomobject]@{
      runId     = 'run-anomaly-1'
      mode      = 'enable'
      operation = 'BuildPackage'
      stages    = @(
        # prepare before addtoken -> out-of-order
        [pscustomobject]@{ name = 'enable-prepare-2025-64';  durationSeconds = 2.0; status = 'ok' },
        [pscustomobject]@{ name = 'enable-addtoken-2025-64'; durationSeconds = 1.0; status = 'ok' },
        # duplicate addtoken
        [pscustomobject]@{ name = 'enable-addtoken-2025-64'; durationSeconds = 1.1; status = 'ok' }
      )
    }

    $run | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $telemetryDir 'dev-mode-run-1.json') -Encoding utf8

    $env:WORKSPACE_ROOT = $repoRoot

    $script = Join-Path $PSScriptRoot 'Summarize-DevModeStageGraph.ps1'
    pwsh -NoLogo -NoProfile -File $script | Out-Null

    $summaryPath = Join-Path $repoRoot 'tests/results/_agent/icon-editor/dev-mode-stage-graph-summary.json'
    Test-Path -LiteralPath $summaryPath | Should -BeTrue

    $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json

    $summary.TotalRuns       | Should -Be 1
    $summary.ExpectedGraphs  | Should -Be 0
    $summary.UnexpectedGraphs | Should -Be 1

    $runSummary = $summary.Runs[0]
    $runSummary.IsExpectedGraph | Should -BeFalse
    $runSummary.Anomalies | Should -Contain 'out-of-order-stage-graph'
    $runSummary.Anomalies | Should -Contain 'duplicate-enable-addtoken'
  }
}
