Describe "Prepare-FixtureViDiffs.ps1" -Tag 'LVCompare','Unit' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
        Set-Variable -Scope Script -Name scriptPath -Value (Join-Path $repoRoot 'src/tools/icon-editor/Prepare-FixtureViDiffs.ps1')
        Test-Path -LiteralPath $script:scriptPath | Should -BeTrue
    }

    It 'creates vi-diff-requests.json with schema, count and requests' {
        $outDir = Join-Path $TestDrive 'vi-diff-out'
        $reportPath = Join-Path $TestDrive 'fixture-report.json'
        # minimal placeholder report content (not used by current stub implementation)
        '{}' | Set-Content -LiteralPath $reportPath -Encoding utf8

        & $script:scriptPath -ReportPath $reportPath -OutputDir $outDir | Out-Null

        Test-Path -LiteralPath $outDir -PathType Container | Should -BeTrue
        $requestsPath = Join-Path $outDir 'vi-diff-requests.json'
        Test-Path -LiteralPath $requestsPath -PathType Leaf | Should -BeTrue

        $json = Get-Content -LiteralPath $requestsPath -Raw | ConvertFrom-Json -Depth 5
        $json.schema | Should -Be 'icon-editor/vi-diff-requests@v1'
        $json.count | Should -BeGreaterThan 0
        ($json.requests | Measure-Object).Count | Should -Be $json.count
        $json.requests[0].relPath | Should -Not -BeNullOrEmpty
    }

    It 'creates output directory if it does not exist' {
        $outDir = Join-Path $TestDrive 'new-dir'
        Test-Path -LiteralPath $outDir | Should -BeFalse
        & $script:scriptPath -ReportPath (Join-Path $TestDrive 'stub.json') -OutputDir $outDir | Out-Null
        Test-Path -LiteralPath $outDir -PathType Container | Should -BeTrue
    }
}
