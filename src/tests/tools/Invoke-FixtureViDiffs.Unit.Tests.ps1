function global:New-RequestsFile {
    param([pscustomobject[]]$Requests, [string]$Path)
    $payload = [pscustomobject]@{
        schema   = 'icon-editor/vi-diff-requests@v1'
        count    = ($Requests | Measure-Object).Count
        requests = $Requests
    }
    $payload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $Path -Encoding utf8
}

Describe 'Invoke-FixtureViDiffs.ps1' -Tag 'LVCompare','Unit' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
        Set-Variable -Scope Script -Name scriptPath -Value (Join-Path $repoRoot 'src/tools/icon-editor/Invoke-FixtureViDiffs.ps1')
        Test-Path -LiteralPath $script:scriptPath | Should -BeTrue
    }

    It 'writes summary + capture metadata when requests exist' {
        $requestsRoot = Join-Path $TestDrive 'requests'
        $capturesRoot = Join-Path $TestDrive 'captures'
        $summaryPath = Join-Path $requestsRoot 'vi-comparison-summary.json'
        $requestsPath = Join-Path $requestsRoot 'vi-diff-requests.json'
        New-Item -ItemType Directory -Path $requestsRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $capturesRoot -Force | Out-Null

        $requests = @(
            [pscustomobject]@{ relPath = 'foo.vi'; name = 'Foo'; category = 'test' },
            [pscustomobject]@{ relPath = 'bar.vi'; name = 'Bar'; category = 'test' }
        )
        New-RequestsFile -Requests $requests -Path $requestsPath

        & $script:scriptPath `
            -RequestsPath $requestsPath `
            -CapturesRoot $capturesRoot `
            -SummaryPath $summaryPath `
            -DryRun:$false `
            -TimeoutSeconds 1 | Out-Null

        Test-Path -LiteralPath $summaryPath | Should -BeTrue
        $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json -Depth 6
        $summary.counts.total | Should -Be 2
        $summary.counts.dryRun | Should -Be 0
        ($summary.requests | Where-Object { $_.status -eq 'different' }).Count | Should -Be 2

        $captureDirs = Get-ChildItem -Directory -Path $capturesRoot
        $captureDirs.Count | Should -Be 2
        $sessionPath = Join-Path ($captureDirs[0].FullName) 'session-index.json'
        Test-Path -LiteralPath $sessionPath | Should -BeTrue
    }

    It 'marks requests as dry-run when requested' {
        $requestsRoot = Join-Path $TestDrive 'requests-dry'
        $capturesRoot = Join-Path $TestDrive 'captures-dry'
        $summaryPath = Join-Path $requestsRoot 'vi-comparison-summary.json'
        $requestsPath = Join-Path $requestsRoot 'vi-diff-requests.json'
        New-Item -ItemType Directory -Path $requestsRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $capturesRoot -Force | Out-Null

        $requests = @(
            [pscustomobject]@{ relPath = 'dry.vi'; name = 'Dry'; category = 'test' }
        )
        New-RequestsFile -Requests $requests -Path $requestsPath

        & $script:scriptPath `
            -RequestsPath $requestsPath `
            -CapturesRoot $capturesRoot `
            -SummaryPath $summaryPath `
            -DryRun `
            -TimeoutSeconds 1 | Out-Null

        $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json -Depth 6
        $summary.counts.total | Should -Be 1
        $summary.counts.dryRun | Should -Be 1
        $summary.requests[0].status | Should -Be 'dry-run'
        (Test-Path -LiteralPath (Join-Path $capturesRoot 'pair-001')) | Should -BeFalse
    }

    It 'handles empty request lists gracefully' {
        $requestsRoot = Join-Path $TestDrive 'requests-empty'
        $capturesRoot = Join-Path $TestDrive 'captures-empty'
        $summaryPath = Join-Path $requestsRoot 'vi-comparison-summary.json'
        $requestsPath = Join-Path $requestsRoot 'vi-diff-requests.json'
        New-Item -ItemType Directory -Path $requestsRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $capturesRoot -Force | Out-Null

        New-RequestsFile -Requests @() -Path $requestsPath

        & $script:scriptPath `
            -RequestsPath $requestsPath `
            -CapturesRoot $capturesRoot `
            -SummaryPath $summaryPath `
            -DryRun `
            -TimeoutSeconds 1 | Out-Null

        $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json -Depth 6
        $summary.counts.total | Should -Be 0
        $summary.requests.Count | Should -Be 0
    }
}
