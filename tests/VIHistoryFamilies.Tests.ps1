#Requires -Version 7.0
#Requires -Modules Pester

param()

Describe 'VI History family summarizer' -Tag 'VIHistory','Summarizer' {
  BeforeAll {
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:summarizer = Join-Path $script:repoRoot 'tests/tools/Summarize-VIHistoryFamilies.ps1'
    Test-Path -LiteralPath $script:summarizer | Should -BeTrue

    $script:familyRoot = Join-Path $script:repoRoot 'tests/results/_agent/vi-history-family-tests'
    if (Test-Path -LiteralPath $script:familyRoot -PathType Container) {
      Remove-Item -LiteralPath $script:familyRoot -Recurse -Force
    }
    New-Item -ItemType Directory -Path $script:familyRoot -Force | Out-Null
  }

  It 'groups VI History summaries into scenario families' {
    # vihistory.ok
    $okDir = New-Item -ItemType Directory -Path (Join-Path $script:familyRoot 'ok-run') -Force
    $okSummary = [ordered]@{
      schema = 'pr-vi-history-summary@v1'
      totals = [ordered]@{
        targets        = 3
        completed      = 3
        diffTargets    = 0
        comparisons    = 3
        diffs          = 0
        errors         = 0
        skippedEntries = 0
      }
    }
    $okSummary | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $okDir.FullName 'vi-history-summary.json') -Encoding utf8

    # vihistory.diff
    $diffDir = New-Item -ItemType Directory -Path (Join-Path $script:familyRoot 'diff-run') -Force
    $diffSummary = [ordered]@{
      schema = 'pr-vi-history-summary@v1'
      totals = [ordered]@{
        targets        = 2
        completed      = 2
        diffTargets    = 2
        comparisons    = 2
        diffs          = 5
        errors         = 0
        skippedEntries = 0
      }
    }
    $diffSummary | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $diffDir.FullName 'vi-history-summary.json') -Encoding utf8

    # vihistory.skipped
    $skippedDir = New-Item -ItemType Directory -Path (Join-Path $script:familyRoot 'skipped-run') -Force
    $skippedSummary = [ordered]@{
      schema = 'pr-vi-history-summary@v1'
      totals = [ordered]@{
        targets        = 1
        completed      = 0
        diffTargets    = 0
        comparisons    = 0
        diffs          = 0
        errors         = 0
        skippedEntries = 1
      }
    }
    $skippedSummary | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $skippedDir.FullName 'vi-history-summary.json') -Encoding utf8

    # vihistory.error
    $errorDir = New-Item -ItemType Directory -Path (Join-Path $script:familyRoot 'error-run') -Force
    $errorSummary = [ordered]@{
      schema = 'pr-vi-history-summary@v1'
      totals = [ordered]@{
        targets        = 2
        completed      = 1
        diffTargets    = 1
        comparisons    = 2
        diffs          = 1
        errors         = 1
        skippedEntries = 0
      }
    }
    $errorSummary | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $errorDir.FullName 'vi-history-summary.json') -Encoding utf8

    $summaryPath = Join-Path $script:familyRoot 'vi-history-family-summary.json'

    pwsh -NoLogo -NoProfile -File $script:summarizer -SummaryRoot $script:familyRoot -OutputPath $summaryPath | Out-Null

    Test-Path -LiteralPath $summaryPath | Should -BeTrue

    $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    $summary.TotalRuns | Should -Be 4

    $families = @{}
    foreach ($entry in $summary.ByFamily) {
      $families[$entry.Family] = $entry.Count
    }

    $families['vihistory.ok']      | Should -Be 1
    $families['vihistory.diff']    | Should -Be 1
    $families['vihistory.skipped'] | Should -Be 1
    $families['vihistory.error']   | Should -Be 1
  }
}

