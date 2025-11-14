#Requires -Version 7.0

Describe 'Invoke-ViCompareLabVIEWCli.ps1' {
    It 'produces a dry-run summary when CLI is disabled' {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).ProviderPath
        $requests = @{
            schema   = 'icon-editor/vi-diff-requests@v1'
            count    = 2
            requests = @(
                @{ name = 'A.vi'; relPath = 'tests/fixtures/A.vi'; base = 'fixtures/A/base.vi'; head = 'fixtures/A/head.vi' },
                @{ name = 'B.vi'; relPath = 'tests/fixtures/B.vi'; baseline = @{ path = 'fixtures/B/base.vi' }; candidate = @{ path = 'fixtures/B/head.vi' } }
            )
        }
        $tempRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
        $requestsPath = Join-Path $tempRoot 'vi-diff-requests.json'
        $requests | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $requestsPath -Encoding UTF8
        $outputRoot = Join-Path $tempRoot 'out'

        $scriptPath = Join-Path $repoRoot 'local-ci' 'windows' 'scripts' 'Invoke-ViCompareLabVIEWCli.ps1'
        pwsh -NoLogo -NoProfile -File $scriptPath `
            -RepoRoot $repoRoot `
            -RequestsPath $requestsPath `
            -OutputRoot $outputRoot `
            -ProbeRoots $tempRoot `
            -DryRun | Out-Null

        $summaryPath = Join-Path $outputRoot 'vi-comparison-summary.json'
        Test-Path -LiteralPath $summaryPath | Should -BeTrue
        $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
        $summary.counts.total | Should -Be 2
        $summary.counts.dryRun | Should -Be 2
        $summary.requests.Count | Should -Be 2
        $summary.requests[0].status | Should -Be 'dry-run'
        Test-Path -LiteralPath (Join-Path $outputRoot 'captures/pair-001/compare-report.html') | Should -BeTrue
    }

    It 'invokes the harness per pair when inputs are resolvable' {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).ProviderPath
        $tempRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

        $fixturesRoot = Join-Path $tempRoot 'fixtures'
        New-Item -ItemType Directory -Path (Join-Path $fixturesRoot 'A') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $fixturesRoot 'B') -Force | Out-Null
        'base' | Set-Content -LiteralPath (Join-Path $fixturesRoot 'A/base.vi')
        'head' | Set-Content -LiteralPath (Join-Path $fixturesRoot 'A/head.vi')
        'base' | Set-Content -LiteralPath (Join-Path $fixturesRoot 'B/base.vi')
        'head' | Set-Content -LiteralPath (Join-Path $fixturesRoot 'B/head.vi')

        $requests = @{
            schema = 'icon-editor/vi-diff-requests@v1'
            count  = 1
            requests = @(
                @{
                    name = 'Pair-A'
                    relPath = 'fixtures/A'
                    base = (Join-Path $fixturesRoot 'A/base.vi')
                    head = (Join-Path $fixturesRoot 'A/head.vi')
                }
            )
        }
        $requestsPath = Join-Path $tempRoot 'vi-diff-requests.json'
        $requests | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $requestsPath -Encoding UTF8
        $outputRoot = Join-Path $tempRoot 'out'

        $harness = Join-Path $tempRoot 'Harness.ps1'
@'
param(
    [string]$BaseVi,
    [string]$HeadVi,
    [string]$LabVIEWPath,
    [string]$OutputRoot
)
New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
@{ schema = 'labview-cli-capture@v1'; base = $BaseVi; head = $HeadVi } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $OutputRoot 'lvcompare-capture.json') -Encoding UTF8
@{ schema = 'session'; message = 'stub' } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $OutputRoot 'session-index.json') -Encoding UTF8
'<html><body>stub</body></html>' | Set-Content -LiteralPath (Join-Path $OutputRoot 'compare-report.html') -Encoding UTF8
exit 1
'@ | Set-Content -LiteralPath $harness -Encoding UTF8

        $labviewExe = Join-Path $tempRoot 'dummy-labview.exe'
        Set-Content -LiteralPath $labviewExe -Value '' -Encoding UTF8

        $scriptPath = Join-Path $repoRoot 'local-ci' 'windows' 'scripts' 'Invoke-ViCompareLabVIEWCli.ps1'
        pwsh -NoLogo -NoProfile -File $scriptPath `
            -RepoRoot $repoRoot `
            -RequestsPath $requestsPath `
            -OutputRoot $outputRoot `
            -ProbeRoots $tempRoot `
            -HarnessScript $harness `
            -LabVIEWExePath $labviewExe `
            -MaxPairs 5 `
            -TimeoutSeconds 5 `
            -NoiseProfile 'legacy' | Out-Null

        $summaryPath = Join-Path $outputRoot 'vi-comparison-summary.json'
        $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
        $summary.counts.total | Should -Be 1
        $summary.counts.different | Should -Be 1
        $summary.requests[0].status | Should -Be 'different'
        $summary.requests[0].artifacts.captureJson | Should -Match 'captures'
    }
}
