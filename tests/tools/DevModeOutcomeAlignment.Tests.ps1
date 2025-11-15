#Requires -Version 7.0
#Requires -Modules Pester

param()

Describe 'DevMode outcome alignment between telemetry and x-cli' -Tag 'DevMode','Outcome','Alignment' {
  It 'produces alignments with no mismatches when outcomes match' {
    $repoRoot = Join-Path $TestDrive 'outcome-align-ok'
    New-Item -ItemType Directory -Path $repoRoot -Force | Out-Null

    $telemetryDir = Join-Path $repoRoot 'tests/results/_agent/icon-editor/dev-mode-run'
    New-Item -ItemType Directory -Path $telemetryDir -Force | Out-Null

    $runId = 'run-align-1'

    $telemetry = [pscustomobject]@{
      schema           = 'icon-editor/dev-mode-run@v1'
      runId            = $runId
      provider         = 'XCliSim'
      status           = 'succeeded'
      operation        = 'BuildPackage'
      requestedVersions = @('2025')
      requestedBitness  = @('64')
    }
    $telemetry | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $telemetryDir 'dev-mode-run-1.json') -Encoding utf8

    $xcliSummaryDir = Join-Path $repoRoot 'tests/results/_agent/icon-editor'
    New-Item -ItemType Directory -Path $xcliSummaryDir -Force | Out-Null

    $byRunId = @(
      [pscustomobject]@{
        RunId      = $runId
        Total      = 1
        Operations = @('enable-addtoken-2025-64')
        Modes      = @('enable')
        ExitCodes  = @(0)
        Outcome    = 'succeeded'
      }
    )

    $xcliSummary = [pscustomobject]@{
      GeneratedAt   = (Get-Date).ToString('o')
      Root          = $repoRoot
      DevmodeDir    = Join-Path $repoRoot 'tools/x-cli-develop/temp_telemetry/labview-devmode'
      TotalRecords  = 1
      ByOperation   = @()
      SchemaVersions = @('<none>')
      ByRunId       = $byRunId
    }

    $xcliSummaryPath = Join-Path $xcliSummaryDir 'xcli-devmode-summary.json'
    $xcliSummary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $xcliSummaryPath -Encoding utf8

    $env:WORKSPACE_ROOT = $repoRoot

    $script = Join-Path $PSScriptRoot 'Summarize-DevModeOutcomeAlignment.ps1'
    pwsh -NoLogo -NoProfile -File $script -XCliSummaryPath $xcliSummaryPath | Out-Null

    $alignmentPath = Join-Path $repoRoot 'tests/results/_agent/icon-editor/dev-mode-outcome-alignment.json'
    Test-Path -LiteralPath $alignmentPath | Should -BeTrue

    $alignment = Get-Content -LiteralPath $alignmentPath -Raw | ConvertFrom-Json

    $alignment.Alignments.Count | Should -Be 1
    $alignment.Mismatches.Count | Should -Be 0

    $entry = $alignment.Alignments[0]
    $entry.RunId           | Should -Be $runId
    $entry.Provider        | Should -Be 'XCliSim'
    $entry.TelemetryStatus | Should -Be 'succeeded'
    $entry.XCliOutcome     | Should -Be 'succeeded'
  }

  It 'flags mismatches when telemetry status and x-cli outcome differ' {
    $repoRoot = Join-Path $TestDrive 'outcome-align-mismatch'
    New-Item -ItemType Directory -Path $repoRoot -Force | Out-Null

    $telemetryDir = Join-Path $repoRoot 'tests/results/_agent/icon-editor/dev-mode-run'
    New-Item -ItemType Directory -Path $telemetryDir -Force | Out-Null

    $runId = 'run-align-2'

    $telemetry = [pscustomobject]@{
      schema           = 'icon-editor/dev-mode-run@v1'
      runId            = $runId
      provider         = 'XCliSim'
      status           = 'degraded'
      operation        = 'BuildPackage'
      requestedVersions = @('2025')
      requestedBitness  = @('64')
    }
    $telemetry | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $telemetryDir 'dev-mode-run-1.json') -Encoding utf8

    $xcliSummaryDir = Join-Path $repoRoot 'tests/results/_agent/icon-editor'
    New-Item -ItemType Directory -Path $xcliSummaryDir -Force | Out-Null

    $byRunId = @(
      [pscustomobject]@{
        RunId      = $runId
        Total      = 1
        Operations = @('enable-addtoken-2025-64')
        Modes      = @('enable')
        ExitCodes  = @(0)
        Outcome    = 'succeeded'
      }
    )

    $xcliSummary = [pscustomobject]@{
      GeneratedAt   = (Get-Date).ToString('o')
      Root          = $repoRoot
      DevmodeDir    = Join-Path $repoRoot 'tools/x-cli-develop/temp_telemetry/labview-devmode'
      TotalRecords  = 1
      ByOperation   = @()
      SchemaVersions = @('<none>')
      ByRunId       = $byRunId
    }

    $xcliSummaryPath = Join-Path $xcliSummaryDir 'xcli-devmode-summary.json'
    $xcliSummary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $xcliSummaryPath -Encoding utf8

    $env:WORKSPACE_ROOT = $repoRoot

    $script = Join-Path $PSScriptRoot 'Summarize-DevModeOutcomeAlignment.ps1'
    pwsh -NoLogo -NoProfile -File $script -XCliSummaryPath $xcliSummaryPath | Out-Null

    $alignmentPath = Join-Path $repoRoot 'tests/results/_agent/icon-editor/dev-mode-outcome-alignment.json'
    Test-Path -LiteralPath $alignmentPath | Should -BeTrue

    $alignment = Get-Content -LiteralPath $alignmentPath -Raw | ConvertFrom-Json

    $alignment.Alignments.Count | Should -Be 1
    $alignment.Mismatches.Count | Should -Be 1

    $mismatch = $alignment.Mismatches[0]
    $mismatch.RunId           | Should -Be $runId
    $mismatch.Provider        | Should -Be 'XCliSim'
    $mismatch.TelemetryStatus | Should -Be 'degraded'
    $mismatch.XCliOutcome     | Should -Be 'succeeded'
  }

  It 'ignores telemetry runs without x-cli RunId matches' {
    $repoRoot = Join-Path $TestDrive 'outcome-align-missing-run'
    New-Item -ItemType Directory -Path $repoRoot -Force | Out-Null

    $telemetryDir = Join-Path $repoRoot 'tests/results/_agent/icon-editor/dev-mode-run'
    New-Item -ItemType Directory -Path $telemetryDir -Force | Out-Null

    $telemetry = [pscustomobject]@{
      schema           = 'icon-editor/dev-mode-run@v1'
      runId            = 'run-no-xcli'
      provider         = 'XCliSim'
      status           = 'succeeded'
      operation        = 'BuildPackage'
      requestedVersions = @('2025')
      requestedBitness  = @('64')
    }
    $telemetry | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $telemetryDir 'dev-mode-run-1.json') -Encoding utf8

    $xcliSummaryDir = Join-Path $repoRoot 'tests/results/_agent/icon-editor'
    New-Item -ItemType Directory -Path $xcliSummaryDir -Force | Out-Null

    $xcliSummary = [pscustomobject]@{
      GeneratedAt   = (Get-Date).ToString('o')
      Root          = $repoRoot
      DevmodeDir    = Join-Path $repoRoot 'tools/x-cli-develop/temp_telemetry/labview-devmode'
      TotalRecords  = 0
      ByOperation   = @()
      SchemaVersions = @('<none>')
      ByRunId       = @()
    }

    $xcliSummaryPath = Join-Path $xcliSummaryDir 'xcli-devmode-summary.json'
    $xcliSummary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $xcliSummaryPath -Encoding utf8

    $env:WORKSPACE_ROOT = $repoRoot

    $script = Join-Path $PSScriptRoot 'Summarize-DevModeOutcomeAlignment.ps1'
    pwsh -NoLogo -NoProfile -File $script -XCliSummaryPath $xcliSummaryPath | Out-Null

    $alignmentPath = Join-Path $repoRoot 'tests/results/_agent/icon-editor/dev-mode-outcome-alignment.json'
    Test-Path -LiteralPath $alignmentPath | Should -BeTrue

    $alignment = Get-Content -LiteralPath $alignmentPath -Raw | ConvertFrom-Json

    $alignment.Alignments.Count | Should -Be 1
    $alignment.Mismatches.Count | Should -Be 0

    $entry = $alignment.Alignments[0]
    $entry.RunId           | Should -Be 'run-no-xcli'
    $entry.XCliOutcome     | Should -Be '<none>'
  }
}

