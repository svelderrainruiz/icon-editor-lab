#Requires -Version 7.0

Describe 'local-ci/windows/stages/37-VICompare.ps1' {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).ProviderPath
        $script:StagePath = Join-Path $script:RepoRoot 'local-ci/windows/stages/37-VICompare.ps1'
    }

    It 'invokes the LabVIEW CLI helper and publishes artifacts' {
        $runRoot = Join-Path $TestDrive 'run'
        $signRoot = Join-Path $TestDrive 'sign'
        New-Item -ItemType Directory -Path $runRoot, $signRoot -Force | Out-Null

        $ubuntuArtifacts = Join-Path $runRoot 'ubuntu-artifacts'
        $viRoot = Join-Path $ubuntuArtifacts 'vi-comparison'
        $payloadDir = Join-Path $viRoot 'RUN-1234'
        New-Item -ItemType Directory -Path $payloadDir -Force | Out-Null

        $fixturesDir = Join-Path $payloadDir 'fixtures'
        New-Item -ItemType Directory -Path $fixturesDir -Force | Out-Null
        $baseVi = Join-Path $fixturesDir 'base.vi'
        $headVi = Join-Path $fixturesDir 'head.vi'
        'base' | Set-Content -LiteralPath $baseVi -Encoding UTF8
        'head' | Set-Content -LiteralPath $headVi -Encoding UTF8

        $ubuntuRunPath = Join-Path $TestDrive 'ubuntu-run'
        New-Item -ItemType Directory -Path $ubuntuRunPath -Force | Out-Null
        $ubuntuManifestPath = Join-Path $ubuntuRunPath 'ubuntu-run.json'
        '{}' | Set-Content -LiteralPath $ubuntuManifestPath -Encoding UTF8
        '{"state":"ready"}' | Set-Content -LiteralPath (Join-Path $ubuntuRunPath '_READY') -Encoding UTF8
        $claimPath = Join-Path $ubuntuRunPath 'windows.claimed'
        @{ watcher = 'test'; claimedAtUtc = (Get-Date).ToUniversalTime().ToString('o') } | ConvertTo-Json | Set-Content -LiteralPath $claimPath -Encoding UTF8

        @{
            ManifestPath = $ubuntuManifestPath
            ExtractedPath = $ubuntuArtifacts
        } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runRoot 'ubuntu-import.json') -Encoding UTF8

        $requests = @{
            schema = 'icon-editor/vi-diff-requests@v1'
            count  = 1
            requests = @(
                @{
                    name = 'fixtures/base.vi'
                    relPath = 'fixtures/base.vi'
                    baseline = @{ path = 'fixtures/base.vi' }
                    candidate = @{ path = 'fixtures/head.vi' }
                }
            )
        }
        $requestsPath = Join-Path $payloadDir 'vi-diff-requests.json'
        $requests | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $requestsPath -Encoding UTF8

        $summaryPath = Join-Path $payloadDir 'vi-comparison-summary.json'
        @{
            schema = 'icon-editor/vi-diff-summary@v1'
            counts = @{ total = 1; dryRun = 1 }
            requests = @()
        } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

        $harness = Join-Path $TestDrive 'Harness.ps1'
@'
param(
    [string]$BaseVi,
    [string]$HeadVi,
    [string]$LabVIEWPath,
    [string]$OutputRoot,
    [string]$NoiseProfile,
    [switch]$RenderReport,
    [switch]$CloseLabVIEW,
    [switch]$CloseLVCompare,
    [int]$TimeoutSeconds
)
New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
@{ schema = 'labview-cli-capture@v1'; base = $BaseVi; head = $HeadVi } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $OutputRoot 'lvcompare-capture.json') -Encoding UTF8
@{ schema = 'session'; message = 'stub' } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $OutputRoot 'session-index.json') -Encoding UTF8
'<html><body>stub</body></html>' | Set-Content -LiteralPath (Join-Path $OutputRoot 'compare-report.html') -Encoding UTF8
exit 1
'@ | Set-Content -LiteralPath $harness -Encoding UTF8

        $labviewExe = Join-Path $TestDrive 'LabVIEW.exe'
        Set-Content -LiteralPath $labviewExe -Value '' -Encoding UTF8

        $context = [pscustomobject]@{
            RepoRoot  = $script:RepoRoot
            RunRoot   = $runRoot
            SignRoot  = $signRoot
            Timestamp = 'WIN-TEST'
            Config    = [pscustomobject]@{
                EnableViCompareCli      = $true
                ViCompareLabVIEWPath    = $labviewExe
                ViCompareHarnessPath    = $harness
                ViCompareMaxPairs       = 5
                ViCompareTimeoutSeconds = 30
                ViCompareNoiseProfile   = 'legacy'
            }
        }

        & $script:StagePath -Context $context

        $publishDir = Join-Path $signRoot 'vi-comparison/windows/WIN-TEST'
        $publishPath = Join-Path $publishDir 'publish.json'
        Test-Path -LiteralPath $publishPath | Should -BeTrue
        $publish = Get-Content -LiteralPath $publishPath -Raw | ConvertFrom-Json
        $publish.ubuntuPayload | Should -Be 'RUN-1234'

        $sharedSummary = Get-Content -LiteralPath (Join-Path $publishDir 'vi-comparison-summary.json') -Raw | ConvertFrom-Json
        $sharedSummary.counts.total | Should -Be 1
        $sharedSummary.counts.different | Should -Be 1
        ($sharedSummary.requests[0].artifacts.captureJson) | Should -Match 'captures'

        $runPublish = Join-Path $ubuntuRunPath 'windows/vi-compare.publish.json'
        Test-Path -LiteralPath $runPublish | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $ubuntuRunPath '_READY') | Should -BeFalse
        $claimData = Get-Content -LiteralPath $claimPath -Raw | ConvertFrom-Json
        $claimData.state | Should -Be 'published'
    }

    It 'skips gracefully when Ubuntu artifacts are unavailable' {
        $runRoot = Join-Path $TestDrive 'run-empty'
        $signRoot = Join-Path $TestDrive 'sign-empty'
        New-Item -ItemType Directory -Path $runRoot, $signRoot -Force | Out-Null

        $context = [pscustomobject]@{
            RepoRoot  = $script:RepoRoot
            RunRoot   = $runRoot
            SignRoot  = $signRoot
            Timestamp = 'WIN-SKIP'
            Config    = [pscustomobject]@{}
        }

        { & $script:StagePath -Context $context } | Should -Not -Throw
        $sharedRoot = Join-Path $signRoot 'vi-comparison'
        Test-Path -LiteralPath $sharedRoot | Should -BeFalse
    }
}
