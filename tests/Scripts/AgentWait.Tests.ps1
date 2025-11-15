$root = $env:WORKSPACE_ROOT
if (-not $root) { $root = '/mnt/data/repo_local' }
if (-not (Test-Path -LiteralPath $root -PathType Container)) {
    $scriptDir = Split-Path -Parent $PSCommandPath
    $probe = $scriptDir
    while ($probe -and (Split-Path -Leaf $probe) -ne 'tests') {
        $next = Split-Path -Parent $probe
        if (-not $next -or $next -eq $probe) { break }
        $probe = $next
    }
    if ($probe -and (Split-Path -Leaf $probe) -eq 'tests') {
        $root = Split-Path -Parent $probe
    }
    else {
        $root = $scriptDir
    }
}
$repoRoot = (Resolve-Path -LiteralPath $root).Path
$tmp = Join-Path $repoRoot '.tmp-tests'
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
. (Join-Path $root 'tests/_helpers/Import-ScriptFunctions.ps1')
$scriptPath = Join-Path $repoRoot 'src/tools/Agent-Wait.ps1'
$scriptExists = Test-Path -LiteralPath $scriptPath -PathType Leaf
if ($scriptExists) {
    Import-ScriptFunctions -Path $scriptPath -FunctionNames @(
        'Invoke-ProcessCapture',
        'Get-AgentRunContext',
        'Start-AgentWait',
        'End-AgentWait'
    ) | Out-Null
}

Describe 'Agent-Wait.ps1' {
    if (-not $scriptExists) {
        It 'skips when Agent-Wait.ps1 is absent' -Skip {
            # File not present in this repo snapshot.
        }
        return
    }
    Context 'Invoke-ProcessCapture' {
        It 'captures stdout, stderr, and exit code from a child process' {
            $inlineCommand = "Write-Output 'STDOUT sample'; [Console]::Error.WriteLine('ERR sample'); exit 5"
            $result = Invoke-ProcessCapture -FileName 'pwsh' -Arguments @('-NoLogo','-NoProfile','-Command',$inlineCommand)
            $result.Code | Should -Be 5
            $result.Out | Should -Match 'STDOUT sample'
            $result.Err | Should -Match 'ERR sample'
        }
    }

    Context 'Get-AgentRunContext' {
        BeforeAll {
            $script:envBackup = @{
                workflow = $env:GITHUB_WORKFLOW
                job      = $env:GITHUB_JOB
                sha      = $env:GITHUB_SHA
                ref      = $env:GITHUB_REF
                actor    = $env:GITHUB_ACTOR
            }
        }

        BeforeEach {
            $env:GITHUB_WORKFLOW = $null
            $env:GITHUB_JOB = $null
            $env:GITHUB_SHA = $null
            $env:GITHUB_REF = $null
            $env:GITHUB_ACTOR = $null
        }

        AfterAll {
            $env:GITHUB_WORKFLOW = $script:envBackup.workflow
            $env:GITHUB_JOB = $script:envBackup.job
            $env:GITHUB_SHA = $script:envBackup.sha
            $env:GITHUB_REF = $script:envBackup.ref
            $env:GITHUB_ACTOR = $script:envBackup.actor
        }

        It 'derives missing fields using git when environment variables are absent' {
            Mock -CommandName Invoke-ProcessCapture -ParameterFilter { $FileName -eq 'git' -and $Arguments -contains '--verify' } -MockWith {
                [pscustomobject]@{ Code = 0; Out = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa`n"; Err = '' }
            }
            Mock -CommandName Invoke-ProcessCapture -ParameterFilter { $FileName -eq 'git' -and $Arguments -contains '--abbrev-ref' } -MockWith {
                [pscustomobject]@{ Code = 0; Out = "develop`n"; Err = '' }
            }

            $context = Get-AgentRunContext
            $context.sha | Should -Match 'a{8}'
            $context.ref | Should -Be 'refs/heads/develop'
            $context.workflow | Should -Be 'local-session'
            $context.job | Should -Be 'manual'
            Assert-MockCalled -CommandName Invoke-ProcessCapture -Times 1 -ParameterFilter { $FileName -eq 'git' -and $Arguments -contains '--verify' }
            Assert-MockCalled -CommandName Invoke-ProcessCapture -Times 1 -ParameterFilter { $FileName -eq 'git' -and $Arguments -contains '--abbrev-ref' }
        }

        It 'uses existing environment metadata when available' {
            $env:GITHUB_WORKFLOW = 'docs'
            $env:GITHUB_JOB = 'links'
            $env:GITHUB_SHA = 'abc123'
            $env:GITHUB_REF = 'refs/heads/main'
            $env:GITHUB_ACTOR = 'bot'
            $context = Get-AgentRunContext
            $context.workflow | Should -Be 'docs'
            $context.job | Should -Be 'links'
            $context.sha | Should -Be 'abc123'
            $context.ref | Should -Be 'refs/heads/main'
            $context.actor | Should -Be 'bot'
        }
    }

    Context 'Start-AgentWait and End-AgentWait' {
        It 'writes a wait marker and records the final result' {
            $resultsDir = Join-Path $TestDrive 'agent-results'
            $marker = Start-AgentWait -Reason 'coverage' -ExpectedSeconds 1 -ResultsDir $resultsDir -Id 'demo'
            Test-Path -LiteralPath $marker | Should -BeTrue

            Start-Sleep -Milliseconds 100
            $result = End-AgentWait -ResultsDir $resultsDir -Id 'demo'
            $result.withinMargin | Should -BeTrue
            $result.markerPath | Should -Be $marker
        }

        It 'returns null when a marker is not found' {
            End-AgentWait -ResultsDir (Join-Path $TestDrive 'missing') -Id 'ghost' | Should -BeNullOrEmpty
        }

        It 'marks results as outside tolerance when elapsed time drifts' {
            $resultsDir = Join-Path $TestDrive 'agent-drift'
            $marker = Start-AgentWait -Reason 'slow-step' -ExpectedSeconds 2 -ResultsDir $resultsDir -Id 'drift-test'
            $record = Get-Content -LiteralPath $marker -Raw | ConvertFrom-Json
            $record.startedUtc = (Get-Date).AddSeconds(-30).ToString('o')
            $record.expectedSeconds = 5
            $record | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $marker -Encoding utf8

            $result = End-AgentWait -ResultsDir $resultsDir -Id 'drift-test' -ToleranceSeconds 0
            $result.withinMargin | Should -BeFalse
            $result.differenceSeconds | Should -BeGreaterThan 0
        }
    }
}


