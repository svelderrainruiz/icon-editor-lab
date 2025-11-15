#Requires -Version 7.0
#Requires -Modules Pester

param()

Describe 'VI History run summarizer' -Tag 'VIHistory','Summary' {
  BeforeAll {
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:summarizer = Join-Path $script:repoRoot '..' 'tests/tools/Summarize-VIHistoryRuns.ps1'
    Test-Path -LiteralPath $script:summarizer | Should -BeTrue
  }

  It 'aggregates targets and statuses across vi-history summary files' {
    $summaryRoot = Join-Path $env:TEMP ('vi-history-runs-' + [guid]::NewGuid().ToString('n'))
    New-Item -ItemType Directory -Path $summaryRoot -Force | Out-Null

    $summary1 = [ordered]@{
      schema      = 'pr-vi-history-summary@v1'
      resultsRoot = (Join-Path $summaryRoot 'results1')
      targets     = @(
        [ordered]@{
          repoPath = 'src/Foo.vi'
          status   = 'completed'
          stats    = [ordered]@{ processed = 2; diffs = 0 }
        },
        [ordered]@{
          repoPath = 'src/Bar.vi'
          status   = 'completed'
          stats    = [ordered]@{ processed = 1; diffs = 1 }
        },
        [ordered]@{
          repoPath = 'src/Baz.vi'
          status   = 'error'
          stats    = [ordered]@{ processed = 0; diffs = 0 }
        }
      )
    }

    $summary2 = [ordered]@{
      schema      = 'pr-vi-history-summary@v1'
      resultsRoot = (Join-Path $summaryRoot 'results2')
      targets     = @(
        [ordered]@{
          repoPath = 'src/Qux.vi'
          status   = 'completed'
          stats    = [ordered]@{ processed = 1; diffs = 1 }
        },
        [ordered]@{
          repoPath = 'src/Skip.vi'
          status   = 'skipped'
          stats    = [ordered]@{ processed = 0; diffs = 0 }
        }
      )
    }

    $s1Path = Join-Path $summaryRoot 'vi-history-summary.json'
    $s2Path = Join-Path $summaryRoot 'nested\vi-history-summary.json'
    New-Item -ItemType Directory -Path (Split-Path -Parent $s2Path) -Force | Out-Null
    $summary1 | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $s1Path -Encoding utf8
    $summary2 | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $s2Path -Encoding utf8

    $outputPath = Join-Path $summaryRoot 'vi-history-run-summary.json'
    pwsh -NoLogo -NoProfile -File $script:summarizer -SummaryRoot $summaryRoot -OutputPath $outputPath | Out-Null

    Test-Path -LiteralPath $outputPath | Should -BeTrue
    $summary = Get-Content -LiteralPath $outputPath -Raw | ConvertFrom-Json

    $summary.TotalSummaries | Should -Be 2
    $summary.TotalTargets   | Should -Be 5
    $summary.Totals.CompletedMatch | Should -Be 1   # Foo
    $summary.Totals.CompletedDiff  | Should -Be 2   # Bar, Qux
    $summary.Totals.Error          | Should -Be 1   # Baz
    $summary.Totals.Skipped        | Should -Be 1   # Skip

    $summary.Runs.Count | Should -Be 2
    ($summary.Runs | Measure-Object -Property Targets -Sum).Sum | Should -Be 5
  }
}
