#Requires -Version 7.0
#Requires -Modules Pester

param()

Describe 'VI Analyzer family summarizer' -Tag 'VIAnalyzer','Summarizer' {
  BeforeAll {
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:summarizer = Join-Path $script:repoRoot 'tests/tools/Summarize-VIAnalyzerFamilies.ps1'
    Test-Path -LiteralPath $script:summarizer | Should -BeTrue

    $script:familyRoot = Join-Path $script:repoRoot 'tests/results/_agent/vi-analyzer-family-tests'
    if (Test-Path -LiteralPath $script:familyRoot -PathType Container) {
      Remove-Item -LiteralPath $script:familyRoot -Recurse -Force
    }
    New-Item -ItemType Directory -Path $script:familyRoot -Force | Out-Null

    $mipHelpersPath = Join-Path $script:repoRoot 'src/tools/icon-editor/MipScenarioHelpers.psm1'
    Import-Module $mipHelpersPath -Force
  }

  It 'groups analyzer runs into scenario families' {
    # vianalyzer.ok
    $okDir = New-Item -ItemType Directory -Path (Join-Path $script:familyRoot 'ok-run') -Force
    $okPayload = [ordered]@{
      exitCode             = 0
      devModeLikelyDisabled = $false
      failureCount         = 0
    }
    $okPayload | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $okDir.FullName 'vi-analyzer.json') -Encoding utf8

    # vianalyzer.devmode-drift
    $driftDir = New-Item -ItemType Directory -Path (Join-Path $script:familyRoot 'drift-run') -Force
    $driftPayload = [ordered]@{
      exitCode             = 1003
      devModeLikelyDisabled = $true
      failureCount         = 0
    }
    $driftPayload | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $driftDir.FullName 'vi-analyzer.json') -Encoding utf8

    # vianalyzer.test-failures
    $failDir = New-Item -ItemType Directory -Path (Join-Path $script:familyRoot 'fail-run') -Force
    $failPayload = [ordered]@{
      exitCode             = 0
      devModeLikelyDisabled = $false
      failureCount         = 3
    }
    $failPayload | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $failDir.FullName 'vi-analyzer.json') -Encoding utf8

    # vianalyzer.error
    $errorDir = New-Item -ItemType Directory -Path (Join-Path $script:familyRoot 'error-run') -Force
    $errorPayload = [ordered]@{
      exitCode             = 5
      devModeLikelyDisabled = $false
      failureCount         = 1
    }
    $errorPayload | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $errorDir.FullName 'vi-analyzer.json') -Encoding utf8

    $summaryPath = Join-Path $script:familyRoot 'vi-analyzer-family-summary.json'

    pwsh -NoLogo -NoProfile -File $script:summarizer -AnalyzerRoot $script:familyRoot -OutputPath $summaryPath | Out-Null

    Test-Path -LiteralPath $summaryPath | Should -BeTrue

    $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    $summary.TotalRuns | Should -Be 4

    $families = @{}
    foreach ($entry in $summary.ByFamily) {
      $families[$entry.Family] = $entry.Count
    }

    $families['vianalyzer.ok']            | Should -Be 1
    $families['vianalyzer.devmode-drift'] | Should -Be 1
    $families['vianalyzer.test-failures'] | Should -Be 1
    $families['vianalyzer.error']         | Should -Be 1
  }
}

