Describe "Render-ViComparisonReport.ps1" -Tag 'LVCompare','Unit' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
        Set-Variable -Scope Script -Name scriptPath -Value (Join-Path $repoRoot 'src/tools/icon-editor/Render-ViComparisonReport.ps1')
        Test-Path -LiteralPath $script:scriptPath | Should -BeTrue
    }

    It 'renders counts and a single request row' {
        $resultsRoot = Join-Path $TestDrive 'results'
        New-Item -ItemType Directory -Path $resultsRoot -Force | Out-Null
        $summaryPath = Join-Path $resultsRoot 'vi-comparison-summary.json'
        $outputPath  = Join-Path $resultsRoot 'vi-comparison-report.md'

        $summary = [pscustomobject]@{
            counts   = [pscustomobject]@{ total = 3; same = 1; different = 1; skipped = 1; dryRun = 0; errors = 0 }
            requests = @([pscustomobject]@{ relPath = 'resource/Stub.vi'; status = 'different'; message = 'delta'; artifacts = @() })
        }
        $summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $summaryPath -Encoding utf8

        & $script:scriptPath -SummaryPath $summaryPath -OutputPath $outputPath | Out-Null

        Test-Path -LiteralPath $outputPath -PathType Leaf | Should -BeTrue
        $content = Get-Content -LiteralPath $outputPath -Raw
        $content | Should -Match '## VI Comparison Report'
        $content | Should -Match 'Compared: 3 total, 1 same, 1 different'
        $content | Should -Match '\| resource/Stub.vi \| different \|'
    }

    It 'renders a fallback when counts are missing' {
        $resultsRoot = Join-Path $TestDrive 'results-nocounts'
        New-Item -ItemType Directory -Path $resultsRoot -Force | Out-Null
        $summaryPath = Join-Path $resultsRoot 'vi-comparison-summary.json'
        $outputPath  = Join-Path $resultsRoot 'vi-comparison-report.md'

        $summary = [pscustomobject]@{ counts = $null }
        $summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $summaryPath -Encoding utf8

        & $script:scriptPath -SummaryPath $summaryPath -OutputPath $outputPath | Out-Null

        Test-Path -LiteralPath $outputPath -PathType Leaf | Should -BeTrue
        $content = Get-Content -LiteralPath $outputPath -Raw
        $content | Should -Match 'No aggregate counts were provided'
        $content | Should -Match '\| \(none\) \| - \| - \| - \|'
    }
}
