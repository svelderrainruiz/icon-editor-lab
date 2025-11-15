#Requires -Version 7.0
#Requires -Modules Pester

param()

Describe 'Summarize-PRVIHistory.ps1 contracts' -Tag 'VIHistory','Summary','Markdown' {
  BeforeAll {
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:scriptPath = Join-Path $script:repoRoot 'tools' 'Summarize-PRVIHistory.ps1'
    Test-Path -LiteralPath $script:scriptPath | Should -BeTrue
  }

  It 'builds markdown and totals from a mixed summary' {
    $summaryPath = Join-Path $TestDrive 'vi-history-summary.json'
    $resultsRoot = Join-Path $TestDrive 'results'
    New-Item -ItemType Directory -Path $resultsRoot -Force | Out-Null

    $targets = @(
      [ordered]@{
        repoPath    = 'src/Foo.vi'
        status      = 'completed'
        changeTypes = @('attributes','front panel')
        stats       = [ordered]@{
          processed = 3
          diffs     = 0
        }
        reportMd    = Join-Path $resultsRoot 'Foo.md'
        reportHtml  = Join-Path $resultsRoot 'Foo.html'
      },
      [ordered]@{
        repoPath    = 'src/Bar.vi'
        status      = 'completed'
        changeTypes = @('block diagram')
        stats       = [ordered]@{
          processed = 2
          diffs     = 1
        }
        reportMd    = Join-Path $resultsRoot 'Bar.md'
        reportHtml  = $null
      },
      [ordered]@{
        repoPath    = 'src/Baz.vi'
        status      = 'error'
        changeTypes = @()
        stats       = [ordered]@{
          processed = 0
          diffs     = 0
        }
        message     = 'Compare failed due to missing VI.'
      }
    )

    $summary = [ordered]@{
      schema      = 'pr-vi-history-summary@v1'
      resultsRoot = $resultsRoot
      targets     = $targets
    }
    $summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $summaryPath -Encoding utf8

    $markdownPath = Join-Path $TestDrive 'vi-history-summary.md'
    $outputJsonPath = Join-Path $TestDrive 'vi-history-summary.enriched.json'

    $result = & $script:scriptPath -SummaryPath $summaryPath -MarkdownPath $markdownPath -OutputJsonPath $outputJsonPath

    $result | Should -Not -BeNullOrEmpty
    $result.totals.targets     | Should -Be 3
    $result.totals.completed   | Should -Be 2
    $result.totals.comparisons | Should -Be 5
    $result.totals.diffs       | Should -Be 1

    Test-Path -LiteralPath $markdownPath | Should -BeTrue
    Test-Path -LiteralPath $outputJsonPath | Should -BeTrue

    $markdown = Get-Content -LiteralPath $markdownPath -Raw
    $markdown | Should -Match '\| VI \| Change \| Comparisons \| Diffs \| Status \| Report / Notes \|'
    $markdown | Should -Match '<code>src/Foo.vi</code>'
    $markdown | Should -Match 'attributes, front panel'
    $markdown | Should -Match '\| <code>src/Bar.vi</code> \| block diagram \| 2 \| 1 \| diff \|'
    $markdown | Should -Match 'Compare failed due to missing VI\.'

    $enriched = Get-Content -LiteralPath $outputJsonPath -Raw | ConvertFrom-Json
    $enriched.totals.targets   | Should -Be 3
    $enriched.targets.Count    | Should -Be 3
    $enriched.markdown         | Should -Not -BeNullOrEmpty
  }

  It 'throws on unexpected schema' {
    $summaryPath = Join-Path $TestDrive 'vi-history-summary-bad.json'
    $bad = [ordered]@{
      schema  = 'pr-vi-history-summary@v2'
      targets = @()
    }
    $bad | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $summaryPath -Encoding utf8

    {
      & $script:scriptPath -SummaryPath $summaryPath
    } | Should -Throw "Unexpected summary schema 'pr-vi-history-summary@v2'. Expected 'pr-vi-history-summary@v1'."
  }
}

