#Requires -Version 7.0
#Requires -Modules Pester

param()

Describe 'VI History anomaly finder' -Tag 'VIHistory','Anomaly','Learning' {
  BeforeAll {
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:finder   = Join-Path $script:repoRoot '..' 'tests/tools/Find-VIHistoryAnomalies.ps1'
    $script:runSummarizer = Join-Path $script:repoRoot '..' 'tests/tools/Summarize-VIHistoryRuns.ps1'

    Test-Path -LiteralPath $script:finder | Should -BeTrue
    Test-Path -LiteralPath $script:runSummarizer | Should -BeTrue
  }

  It 'returns $null and warns when no summaries exist' {
    $root = Join-Path $TestDrive 'vihistory-anomaly-none'
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    $summaryRoot = Join-Path $root 'tests/results/pr-vi-history'
    New-Item -ItemType Directory -Path $summaryRoot -Force | Out-Null

    $env:WORKSPACE_ROOT = $root

    $result = & $script:finder -SummaryRoot $summaryRoot

    # No summaries -> no anomaly object returned.
    $result | Should -BeNullOrEmpty
  }

  It 'selects the run with the highest error/diff score as the anomaly candidate' {
    $root = Join-Path $TestDrive 'vihistory-anomaly-scores'
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    $summaryRoot = Join-Path $root 'tests/results/pr-vi-history'
    New-Item -ItemType Directory -Path $summaryRoot -Force | Out-Null

    # First run: some diffs, no errors.
    $run1Dir = New-Item -ItemType Directory -Path (Join-Path $summaryRoot 'run1') -Force
    $run1Summary = [ordered]@{
      schema = 'pr-vi-history-summary@v1'
      targets = @(
        [ordered]@{
          status = 'completed'
          stats  = @{ diffs = 1 }
        },
        [ordered]@{
          status = 'completed'
          stats  = @{ diffs = 0 }
        }
      )
    }
    $run1Summary | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $run1Dir.FullName 'vi-history-summary.json') -Encoding utf8

    # Second run: more diffs, still no errors.
    $run2Dir = New-Item -ItemType Directory -Path (Join-Path $summaryRoot 'run2') -Force
    $run2Summary = [ordered]@{
      schema = 'pr-vi-history-summary@v1'
      targets = @(
        [ordered]@{
          status = 'completed'
          stats  = @{ diffs = 3 }
        },
        [ordered]@{
          status = 'completed'
          stats  = @{ diffs = 0 }
        }
      )
    }
    $run2Summary | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $run2Dir.FullName 'vi-history-summary.json') -Encoding utf8

    # Third run: errors present (should dominate score).
    $run3Dir = New-Item -ItemType Directory -Path (Join-Path $summaryRoot 'run3') -Force
    $run3Summary = [ordered]@{
      schema = 'pr-vi-history-summary@v1'
      targets = @(
        [ordered]@{
          status = 'error'
          stats  = @{ diffs = 0 }
        },
        [ordered]@{
          status = 'completed'
          stats  = @{ diffs = 0 }
        }
      )
    }
    $run3Summary | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $run3Dir.FullName 'vi-history-summary.json') -Encoding utf8

    $env:WORKSPACE_ROOT = $root

    $result = & $script:finder -SummaryRoot $summaryRoot

    $result | Should -Not -BeNullOrEmpty
    $result.Kind | Should -Be 'vihistory-anomaly-candidate'
    $result.FilePath | Should -Be (Resolve-Path -LiteralPath (Join-Path $run3Dir.FullName 'vi-history-summary.json')).ProviderPath
    $result.Error | Should -Be 1
    $result.CompletedDiff | Should -Be 0
    $result.Score | Should -BeGreaterThan 0
    $result.Hint | Should -Match 'status=''error'''
  }
}
