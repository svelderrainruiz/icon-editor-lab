#Requires -Version 7.0

Describe 'Watch-Windows-VI-Publish hook' {
    BeforeAll {
        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '../..')
        Set-Variable -Name RepoRoot -Value $repoRoot -Scope Script
    }

    It 'renders markdown/html when a matching publish exists' {
        $runStamp = 'TEST-RUN-{0}' -f ([guid]::NewGuid().ToString('N').Substring(0,8))
        $windowsStamp = 'WIN-{0}' -f ([guid]::NewGuid().ToString('N').Substring(0,8))

        $runDir = Join-Path $script:RepoRoot "out/local-ci-ubuntu/$runStamp"
        $windowsRoot = Join-Path $script:RepoRoot "out/vi-comparison/windows"
        $windowsDir = Join-Path $windowsRoot $windowsStamp

        Remove-Item -LiteralPath $runDir -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $windowsDir -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath (Join-Path $script:RepoRoot "out/vi-comparison/$runStamp") -Recurse -Force -ErrorAction SilentlyContinue

        New-Item -ItemType Directory -Path $runDir -Force | Out-Null
        New-Item -ItemType Directory -Path $windowsDir -Force | Out-Null

        $summaryPath = Join-Path $windowsDir 'vi-comparison-summary.json'
        $requestsPath = Join-Path $windowsDir 'vi-diff-requests.json'
        @{
            schema = 'icon-editor/vi-diff-summary@v1'
            counts = @{
                total = 1; same = 0; different = 1; skipped = 0; dryRun = 0; errors = 0
            }
            requests = @(
                @{
                    relPath = 'src/VIs/demo.vi'
                    status  = 'different'
                    message = 'real'
                    artifacts = @{
                        captureJson = 'captures/demo/capture.json'
                    }
                }
            )
        } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
        @{
            schema = 'icon-editor/vi-diff-requests@v1'
            count  = 1
            requests = @(
                @{ relPath = 'src/VIs/demo.vi'; name = 'demo.vi'; category = 'sample' }
            )
        } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $requestsPath -Encoding UTF8

        @{
            schema        = 'vi-compare/publish@v1'
            ubuntuPayload = $runStamp
            windowsRun    = $windowsStamp
            paths         = @{
                runRoot = @{
                    root     = $windowsDir
                    summary  = $summaryPath
                    requests = $requestsPath
                }
            }
        } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $windowsDir 'publish.json') -Encoding UTF8

        $stateDir = Join-Path $script:RepoRoot 'out/local-ci-ubuntu/watchers/test-state'
        Remove-Item -LiteralPath $stateDir -Recurse -Force -ErrorAction SilentlyContinue

        $watcher = Join-Path -Path $script:RepoRoot -ChildPath 'local-ci/ubuntu/watchers/watch-windows-vi-publish.sh'
        & bash $watcher `
            --windows-root $windowsRoot `
            --state-dir $stateDir `
            --log-dir $stateDir `
            --run $runStamp `
            --once | Out-Null

        $logPath = Join-Path $stateDir 'vi-publish-watcher.log'
        Test-Path -LiteralPath $logPath | Should -BeTrue

        $renderedSummary = Join-Path $script:RepoRoot "out/vi-comparison/$runStamp/vi-comparison-summary.json"
        Test-Path -LiteralPath $renderedSummary | Should -BeTrue
        $json = Get-Content -LiteralPath $renderedSummary -Raw | ConvertFrom-Json
        $json.counts.total | Should -Be 1
    }

    It 'supports dry-run mode' {
        $runStamp = 'TEST-RUN-DRY'
        $windowsStamp = 'WIN-DRY'

        $runDir = Join-Path $script:RepoRoot "out/local-ci-ubuntu/$runStamp"
        $windowsDir = Join-Path $script:RepoRoot "out/vi-comparison/windows/$windowsStamp"
        Remove-Item -LiteralPath $runDir -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $windowsDir -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Path $runDir -Force | Out-Null
        New-Item -ItemType Directory -Path $windowsDir -Force | Out-Null

        $summaryPath = Join-Path $windowsDir 'vi-comparison-summary.json'
        $requestsPath = Join-Path $windowsDir 'vi-diff-requests.json'
        [pscustomobject]@{ counts = @{}; requests = @() } | ConvertTo-Json | Set-Content -LiteralPath $summaryPath -Encoding UTF8
        @{ requests = @() } | ConvertTo-Json | Set-Content -LiteralPath $requestsPath -Encoding UTF8
        @{
            schema        = 'vi-compare/publish@v1'
            ubuntuPayload = $runStamp
            windowsRun    = $windowsStamp
            paths         = @{
                runRoot = @{
                    root     = $windowsDir
                    summary  = $summaryPath
                    requests = $requestsPath
                }
            }
        } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $windowsDir 'publish.json') -Encoding UTF8

        $stateDir = Join-Path $script:RepoRoot 'out/local-ci-ubuntu/watchers/test-dry'
        Remove-Item -LiteralPath $stateDir -Recurse -Force -ErrorAction SilentlyContinue

        $watcher = Join-Path -Path $script:RepoRoot -ChildPath 'local-ci/ubuntu/watchers/watch-windows-vi-publish.sh'
        & bash $watcher `
            --windows-root (Join-Path $script:RepoRoot 'out/vi-comparison/windows') `
            --state-dir $stateDir `
            --log-dir $stateDir `
            --run $runStamp `
            --once `
            --dry-run | Out-Null

        $logPath = Join-Path $stateDir 'vi-publish-watcher.log'
        Test-Path -LiteralPath $logPath | Should -BeTrue

        $rendered = Join-Path $script:RepoRoot "out/vi-comparison/$runStamp/vi-comparison-summary.json"
        Test-Path -LiteralPath $rendered | Should -BeFalse
    }
}
