[CmdletBinding()]
param()
#Requires -Version 7.0

function script:New-TestLVProvider {
    param(
        [string]$Name = 'ProviderA',
        [string]$BinaryPath,
        [scriptblock]$Supports = { param($op) $true },
        [scriptblock]$ArgsBuilder = { param($op,$params) @('--operation',$op) }
    )
    $provider = [pscustomobject]@{
        ScriptName   = $Name
        ScriptBinary = $BinaryPath
    }
    $provider | Add-Member -MemberType ScriptMethod -Name Name -Value { $this.ScriptName } -Force
    $provider | Add-Member -MemberType ScriptMethod -Name ResolveBinaryPath -Value { $this.ScriptBinary } -Force
    $provider | Add-Member -MemberType ScriptMethod -Name Supports -Value $Supports -Force
    $provider | Add-Member -MemberType ScriptMethod -Name BuildArgs -Value $ArgsBuilder -Force
    return $provider
}

Describe 'LabVIEWCli utility helpers' -Tag 'Unit','Tools','LabVIEWCli' {
    BeforeAll {
        $here = $PSScriptRoot
        if (-not $here -and $PSCommandPath) {
            $here = Split-Path -Parent $PSCommandPath
        }
        if (-not $here -and $MyInvocation.MyCommand.Path) {
            $here = Split-Path -Parent $MyInvocation.MyCommand.Path
        }
        if (-not $here) {
            throw 'Unable to determine test location.'
        }
        $script:RepoRoot = (Resolve-Path (Join-Path $here '..\..\..')).Path
        $script:modulePath = (Resolve-Path (Join-Path $script:RepoRoot 'src/tools/LabVIEWCli.psm1')).Path
        if (Get-Module -Name LabVIEWCli -ErrorAction SilentlyContinue) {
            Remove-Module LabVIEWCli -Force -ErrorAction SilentlyContinue
        }
        Import-Module -Name $script:modulePath -Force -ErrorAction Stop
    }

    AfterAll {
        if (Get-Module -Name LabVIEWCli -ErrorAction SilentlyContinue) {
            Remove-Module LabVIEWCli -Force -ErrorAction SilentlyContinue
        }
    }

    AfterEach {
        if (Test-Path Env:ICON_EDITOR_LV_PROVIDER_ROOT) {
            Remove-Item Env:ICON_EDITOR_LV_PROVIDER_ROOT -ErrorAction SilentlyContinue
        }
        if (Test-Path Env:LVCLI_PROVIDER) {
            Remove-Item Env:LVCLI_PROVIDER -ErrorAction SilentlyContinue
        }
    }

    Context 'Resolve-LVRepoRoot' {
        It 'returns git root when git succeeds' {
            Mock -CommandName git -ModuleName LabVIEWCli { "C:\repo`n" }

            InModuleScope LabVIEWCli {
                Resolve-LVRepoRoot -StartPath 'C:\repo\child' -Confirm:$false | Should -Be 'C:\repo'
            }
        }

        It 'falls back to the resolved path when git fails' {
            Mock -CommandName git -ModuleName LabVIEWCli { throw 'git failed' }
            $start = Join-Path $TestDrive 'workspace\sub'
            New-Item -ItemType Directory -Path $start -Force | Out-Null

            InModuleScope LabVIEWCli -ScriptBlock {
                param($startPath)
                Resolve-LVRepoRoot -StartPath $startPath -Confirm:$false | Should -Be (Resolve-Path $startPath).Path
            } -ArgumentList $start
        }
    }

    Context 'Command-line formatting helpers' {
        It 'wraps tokens with quotes when whitespace present' {
            InModuleScope LabVIEWCli {
                Format-LVCommandToken -Token 'my path\bin.exe' -Confirm:$false | Should -Be '"my path\\bin.exe"'
            }
        }

        It 'builds command lines with formatted tokens' {
            InModuleScope LabVIEWCli {
                $line = Format-LVCommandLine -Binary 'tool.exe' -Arguments @('foo', 'bar baz') -Confirm:$false
                $line | Should -Be "tool.exe foo `"bar baz`""
            }
        }

        It 'converts relative paths to absolute paths' {
            Push-Location $TestDrive
            try {
                $relative = '.\file.txt'
                Set-Content -Path $relative -Value 'data'
                $expected = (Resolve-Path $relative).Path
                InModuleScope LabVIEWCli -ScriptBlock {
                    param($pathValue, $expectedPath)
                    Convert-ToAbsolutePath -PathValue $pathValue -Confirm:$false | Should -Be $expectedPath
                } -ArgumentList $relative, $expected
            }
            finally {
                Pop-Location
            }
        }
    }

    Context 'Operation metadata' {
        It 'returns operation specs from the bundled JSON' {
            InModuleScope LabVIEWCli {
                $spec = Get-LVOperationSpec -Operation 'CloseLabVIEW' -Confirm:$false
                $spec.name | Should -Be 'CloseLabVIEW'
                $spec.parameters | Should -Not -BeNullOrEmpty
            }
        }

        It 'throws for unknown operations' {
            InModuleScope LabVIEWCli {
                { Get-LVOperationSpec -Operation 'does-not-exist' -Confirm:$false } | Should -Throw '*Unknown LabVIEW CLI operation*'
            }
        }
    }

    Context 'Import-LVProviderModules' {
        It 'discovers providers from override root' {
            $providerRoot = Join-Path $TestDrive ([guid]::NewGuid().Guid)
            $alphaDir = Join-Path $providerRoot 'alpha'
            $betaDir  = Join-Path $providerRoot 'beta'
            New-Item -ItemType Directory -Force -Path $alphaDir,$betaDir | Out-Null
@'
function New-LVProvider {
    $provider = [pscustomobject]@{}
    $provider | Add-Member ScriptMethod Name { 'Alpha' } -Force
    $provider | Add-Member ScriptMethod ResolveBinaryPath { 'C:\alpha\lv.exe' } -Force
    $provider | Add-Member ScriptMethod Supports { param($op) $op -eq 'RunVI' } -Force
    $provider | Add-Member ScriptMethod BuildArgs { param($op,$params) @('--alpha') } -Force
    return $provider
}
'@ | Set-Content -LiteralPath (Join-Path $alphaDir 'Provider.psm1') -Encoding utf8
@'
function New-LVProvider {
    $provider = [pscustomobject]@{}
    $provider | Add-Member ScriptMethod Name { 'Beta' } -Force
    $provider | Add-Member ScriptMethod ResolveBinaryPath { 'C:\beta\lv.exe' } -Force
    $provider | Add-Member ScriptMethod Supports { param($op) $op -eq 'RunVIAnalyzer' } -Force
    $provider | Add-Member ScriptMethod BuildArgs { param($op,$params) @('--beta') } -Force
    return $provider
}
'@ | Set-Content -LiteralPath (Join-Path $betaDir 'Provider.psm1') -Encoding utf8
            $resolved = (Resolve-Path $providerRoot).Path
            Set-Item Env:ICON_EDITOR_LV_PROVIDER_ROOT -Value $resolved
            InModuleScope LabVIEWCli {
                $script:Providers.Clear()
                Import-LVProviderModules -Confirm:$false
                (Get-LVProviders | ForEach-Object { $_.Name() }) | Should -Contain 'Alpha'
                (Get-LVProviders | ForEach-Object { $_.Name() }) | Should -Contain 'Beta'
            }
        }

        It 'writes a warning when provider factory returns null' {
            $providerRoot = Join-Path $TestDrive ([guid]::NewGuid().Guid)
            $invalidDir = Join-Path $providerRoot 'invalid'
            New-Item -ItemType Directory -Force -Path $invalidDir | Out-Null
@'
function New-LVProvider { return $null }
'@ | Set-Content -LiteralPath (Join-Path $invalidDir 'Provider.psm1') -Encoding utf8
            Set-Item Env:ICON_EDITOR_LV_PROVIDER_ROOT -Value (Resolve-Path $providerRoot).Path
            InModuleScope LabVIEWCli {
                $script:Providers.Clear()
                Mock -CommandName Write-Warning -ModuleName LabVIEWCli
                Import-LVProviderModules -Confirm:$false
                Assert-MockCalled -CommandName Write-Warning -ModuleName LabVIEWCli -Times 1
                (Get-LVProviders | Measure-Object).Count | Should -Be 0
            }
        }
    }

    Context 'Invoke-LVOperation (preview)' {
        It 'returns command details without launching process' {
            $binary = Join-Path $TestDrive 'lv-preview.exe'
            Set-Content -Path $binary -Value '' | Out-Null
            InModuleScope LabVIEWCli {
                param($binPath)
                $script:Providers.Clear()
                $provider = New-TestLVProvider -Name 'Previewer' -BinaryPath $binPath -Supports { param($op) $op -eq 'RunVI' } -ArgsBuilder {
                    param($op,$params)
                    @('--run',$params.viPath)
                }
                Register-LVProvider -Provider $provider -Confirm:$false
                Mock -ModuleName LabVIEWCli -CommandName Initialize-LabVIEWCliPidTracker -MockWith {
                    throw 'Preview path should not touch PID tracker initialization.'
                }
                $result = Invoke-LVOperation -Operation 'RunVI' -Params @{ viPath = 'C:\proj\demo.vi' } -Provider 'Previewer' -Preview
                $result.provider | Should -Be 'Previewer'
                $result.command | Should -Match '--run'
                $result.normalizedParams.viPath | Should -Match 'demo.vi'
            } -ArgumentList $binary
        }
    }

    Context 'Provider registration and selection' {
        It 'registers providers and resolves explicit requests' {
            $binary = Join-Path $TestDrive 'lvcli.exe'
            Set-Content -Path $binary -Value '' | Out-Null
            InModuleScope LabVIEWCli {
                param($binPath)
                $script:Providers.Clear()
                $provider = New-TestLVProvider -Name 'Alpha' -BinaryPath $binPath -Supports { param($op) $op -eq 'RunVI' }
                Register-LVProvider -Provider $provider -Confirm:$false
                (Get-LVProviders | Measure-Object).Count | Should -Be 1
                (Get-LVProviderByName -Name 'alpha').Name() | Should -Be 'Alpha'
                $selected = Select-LVProvider -Operation 'RunVI' -RequestedProvider 'Alpha' -Confirm:$false
                $selected.ProviderName | Should -Be 'Alpha'
            } -ArgumentList $binary
        }

        It 'rejects providers missing required methods' {
            InModuleScope LabVIEWCli {
                { Register-LVProvider -Provider ([pscustomobject]@{}) -Confirm:$false } | Should -Throw '*missing required method*'
            }
        }

        It 'honors LVCLI_PROVIDER environment override for auto selection' {
            $binary = Join-Path $TestDrive 'lvcli-auto.exe'
            Set-Content -Path $binary -Value '' | Out-Null
            Set-Item Env:LVCLI_PROVIDER -Value 'Beta'
            InModuleScope LabVIEWCli {
                param($binPath)
                $script:Providers.Clear()
                $alpha = New-TestLVProvider -Name 'Alpha' -BinaryPath (Join-Path $env:TEMP 'missing.exe') -Supports { param($op) $true }
                $beta  = New-TestLVProvider -Name 'Beta'  -BinaryPath $binPath -Supports { param($op) $op -eq 'RunVI' }
                Register-LVProvider -Provider $alpha -Confirm:$false
                Register-LVProvider -Provider $beta -Confirm:$false
                $selected = Select-LVProvider -Operation 'RunVI' -RequestedProvider 'auto' -Confirm:$false
                $selected.ProviderName | Should -Be 'Beta'
            } -ArgumentList $binary
        }

        It 'skips providers with missing binaries when auto-selecting' {
            $valid = Join-Path $TestDrive 'lvcli-valid.exe'
            Set-Content -Path $valid -Value '' | Out-Null
            InModuleScope LabVIEWCli {
                param($binPath)
                $script:Providers.Clear()
                $alpha = New-TestLVProvider -Name 'Alpha' -BinaryPath (Join-Path $env:TEMP 'missing.exe') -Supports { param($op) $true }
                $beta  = New-TestLVProvider -Name 'Beta'  -BinaryPath $binPath -Supports { param($op) $op -eq 'RunVI' }
                Register-LVProvider -Provider $alpha -Confirm:$false
                Register-LVProvider -Provider $beta -Confirm:$false
                $selected = Select-LVProvider -Operation 'RunVI' -RequestedProvider 'auto' -Confirm:$false
                $selected.ProviderName | Should -Be 'Beta'
                $selected.Binary | Should -Be (Resolve-Path $binPath).Path
            } -ArgumentList $valid
        }

        It 'throws when explicit provider is not registered' {
            InModuleScope LabVIEWCli {
                $script:Providers.Clear()
                { Select-LVProvider -Operation 'RunVI' -RequestedProvider 'Missing' } | Should -Throw '*Missing*'
            }
        }
    }

    Context 'Invoke-LVOperation runtime behavior' {
        It 'injects PID tracker payload after a successful run' {
            $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
            InModuleScope LabVIEWCli {
                param($shell)
                $script:Providers.Clear()
                $provider = New-TestLVProvider -Name 'Shell' -BinaryPath $shell -Supports { param($op) $true } -ArgsBuilder {
                    param($op,$params) @('-NoLogo','-Command',"Write-Output 'cli-ok'")
                }
                Register-LVProvider -Provider $provider -Confirm:$false
                Mock -ModuleName LabVIEWCli -CommandName Set-LVHeadlessEnv -MockWith { @{} }
                Mock -ModuleName LabVIEWCli -CommandName Restore-LVHeadlessEnv -MockWith { }
                Mock -ModuleName LabVIEWCli -CommandName Initialize-LabVIEWCliPidTracker -MockWith {
                    $script:LabVIEWPidTrackerLoaded = $true
                    $script:LabVIEWPidTrackerPath = Join-Path $env:TEMP 'labview-pid.json'
                    $script:LabVIEWPidTrackerRelativePath = 'tests/results/_cli/_agent/labview-pid.json'
                    $state = [pscustomobject]@{ Pid = 4321; Reused = $false }
                    $script:LabVIEWPidTrackerState = $state
                    $script:LabVIEWPidTrackerInitialState = $state
                }
                Mock -ModuleName LabVIEWCli -CommandName Finalize-LabVIEWCliPidTracker -MockWith {
                    param($Source,$Operation,$Provider,$ExitCode,$TimedOut,$CliArgs,$ElapsedSeconds,$Binary,$ErrorMessage)
                    $script:LabVIEWPidTrackerFinalState = [pscustomobject]@{
                        Observation  = [pscustomobject]@{ action = 'finalize'; note = 'ok' }
                        Context      = [pscustomobject]@{ stage = $Source; exitCode = $ExitCode; provider = $Provider }
                        ContextSource= $Source
                    }
                    $script:LabVIEWPidTrackerFinalized = $true
                    $script:LabVIEWPidTrackerFinalContext = $script:LabVIEWPidTrackerFinalState.Context
                    $script:LabVIEWPidTrackerFinalContextSource = $Source
                }

                $result = Invoke-LVOperation -Operation 'RunVI' -Params @{ viPath = 'C:\proj\demo.vi' } -Provider 'Shell' -TimeoutSeconds 5
                $result.ok | Should -BeTrue
                $result | Get-Member -Name labviewPidTracker | Should -Not -BeNullOrEmpty
                $result.labviewPidTracker.final.context.provider | Should -Be 'Shell'
                $result.labviewPidTracker.final.observation.note | Should -Be 'ok'
                Assert-MockCalled -ModuleName LabVIEWCli -CommandName Finalize-LabVIEWCliPidTracker -Times 1
            } -ArgumentList $pwsh
        }

        It 'throws on timeout and finalizes PID tracker with error context' {
            $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
            InModuleScope LabVIEWCli {
                param($shell)
                $script:Providers.Clear()
                $provider = New-TestLVProvider -Name 'Slow' -BinaryPath $shell -Supports { param($op) $true } -ArgsBuilder {
                    param($op,$params) @('-NoLogo','-Command','Start-Sleep -Seconds 2')
                }
                Register-LVProvider -Provider $provider -Confirm:$false
                Mock -ModuleName LabVIEWCli -CommandName Set-LVHeadlessEnv -MockWith { @{} }
                Mock -ModuleName LabVIEWCli -CommandName Restore-LVHeadlessEnv -MockWith { }
                Mock -ModuleName LabVIEWCli -CommandName Initialize-LabVIEWCliPidTracker -MockWith {
                    $script:LabVIEWPidTrackerLoaded = $true
                    $script:LabVIEWPidTrackerPath = Join-Path $env:TEMP 'labview-pid-timeout.json'
                    $state = [pscustomobject]@{ Pid = 999; Reused = $false }
                    $script:LabVIEWPidTrackerState = $state
                    $script:LabVIEWPidTrackerInitialState = $state
                }
                $script:lastFinalize = $null
                Mock -ModuleName LabVIEWCli -CommandName Finalize-LabVIEWCliPidTracker -MockWith {
                    param($Source,$Operation,$Provider,$ExitCode,$TimedOut,$CliArgs,$ElapsedSeconds,$Binary,$ErrorMessage)
                    $script:lastFinalize = [pscustomobject]@{
                        Source    = $Source
                        TimedOut  = $TimedOut
                        Error     = $ErrorMessage
                        Provider  = $Provider
                    }
                }

                { Invoke-LVOperation -Operation 'RunVI' -Params @{ viPath = 'C:\proj\slow.vi' } -Provider 'Slow' -TimeoutSeconds 0 } | Should -Throw '*timed out*'
                $script:lastFinalize | Should -Not -BeNullOrEmpty
                $script:lastFinalize.TimedOut | Should -BeTrue
                $script:lastFinalize.Error | Should -Match 'timed out'
            } -ArgumentList $pwsh
        }

        It 'finalizes tracker with fallback context when initialization fails' {
            $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
            InModuleScope LabVIEWCli {
                param($shell)
                $script:Providers.Clear()
                $provider = New-TestLVProvider -Name 'Shell' -BinaryPath $shell -Supports { param($op) $true } -ArgsBuilder {
                    param($op,$params) @('-NoLogo','-Command',"Write-Output 'cli-ok'")
                }
                Register-LVProvider -Provider $provider -Confirm:$false
                Mock -ModuleName LabVIEWCli -CommandName Initialize-LabVIEWCliPidTracker -MockWith {
                    $script:LabVIEWPidTrackerLoaded = $false
                    $script:LabVIEWPidTrackerPath = $null
                    throw 'init failed'
                }
                Mock -ModuleName LabVIEWCli -CommandName Finalize-LabVIEWCliPidTracker -MockWith { throw 'should not finalize' }
                Mock -ModuleName LabVIEWCli -CommandName Write-LVOperationEvent -MockWith { }
                try {
                    Invoke-LVOperation -Operation 'RunVI' -Params @{ viPath = 'C:\proj\demo.vi' } -Provider 'Shell' -TimeoutSeconds 5 | Out-Null
                } catch {}
                $payload = Get-LabVIEWCliPidTracker
                $payload.final.context.exitCode | Should -Be 0
                $payload.final.contextSource | Should -Be 'labview-cli:operation'
            } -ArgumentList $pwsh
        }

        It 'enforces sentinel TTL suppression with warning guards' {
            $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
            $vi1 = Join-Path $TestDrive 'base.vi'
            $vi2 = Join-Path $TestDrive 'head.vi'
            Set-Content -Path $vi1 -Value '' | Out-Null
            Set-Content -Path $vi2 -Value '' | Out-Null
            Set-Item Env:COMPAREVI_CLI_SENTINEL_TTL -Value '120'
            Set-Item Env:COMPAREVI_WARN_CLI_IN_GIT -Value '1'
            Set-Item Env:COMPAREVI_SUPPRESS_CLI_IN_GIT -Value '1'
            Set-Item Env:GIT_DIR -Value '.git'
            $sentinel = Join-Path $TestDrive 'comparevi.sentinel'
            Set-Content -Path $sentinel -Value '' -Encoding utf8
            (Get-Item $sentinel).LastWriteTimeUtc = [DateTime]::UtcNow
            Mock -ModuleName LabVIEWCli -CommandName Get-CompareCliSentinelPath -MockWith { $sentinel }
            InModuleScope LabVIEWCli {
                param($shell,$baseVi,$headVi)
                $script:Providers.Clear()
                $provider = New-TestLVProvider -Name 'Shell' -BinaryPath $shell -Supports { param($op) $op -eq 'CreateComparisonReport' } -ArgsBuilder {
                    param($op,$params) @('-NoLogo','-Command',"Write-Output 'compare'")
                }
                Register-LVProvider -Provider $provider -Confirm:$false
                $result = Invoke-LVOperation -Operation 'CreateComparisonReport' -Params @{ vi1 = $baseVi; vi2 = $headVi } -Provider 'Shell' -TimeoutSeconds 5
                $result.skipped | Should -BeTrue
                $result.skipReason | Should -Be 'git-context'
            } -ArgumentList $pwsh,$vi1,$vi2
            Remove-Item Env:COMPAREVI_CLI_SENTINEL_TTL,Env:COMPAREVI_WARN_CLI_IN_GIT,Env:COMPAREVI_SUPPRESS_CLI_IN_GIT,Env:GIT_DIR -ErrorAction SilentlyContinue
        }
    }

    Context 'Provider fallback resolution' {
        It 'resolves provider modules when selection only returns a name string' {
            $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
            InModuleScope LabVIEWCli {
                param($shell)
                $script:Providers.Clear()
                $provider = New-TestLVProvider -Name 'Fallback' -BinaryPath $shell -Supports { param($op) $true } -ArgsBuilder {
                    @('-NoLogo','-Command',"Write-Output 'fallback-run'")
                }
                Register-LVProvider -Provider $provider -Confirm:$false
                $script:FallbackShell = $shell
                Mock -ModuleName LabVIEWCli -CommandName Select-LVProvider -MockWith {
                    param($Operation,$RequestedProvider)
                    [pscustomobject]@{
                        Provider     = 'Fallback'
                        ProviderName = $null
                        Binary       = $script:FallbackShell
                    }
                }
                Mock -ModuleName LabVIEWCli -CommandName Set-LVHeadlessEnv -MockWith { @{} }
                Mock -ModuleName LabVIEWCli -CommandName Restore-LVHeadlessEnv -MockWith {}
                Mock -ModuleName LabVIEWCli -CommandName Initialize-LabVIEWCliPidTracker -MockWith {}
                Mock -ModuleName LabVIEWCli -CommandName Finalize-LabVIEWCliPidTracker -MockWith {}

                $result = Invoke-LVOperation -Operation 'RunVI' -Params @{ viPath = 'C:\proj\demo.vi' } -Provider 'Fallback'

                $result.provider | Should -Be 'Fallback'
                $result.command | Should -Match 'fallback-run'
                Assert-MockCalled -ModuleName LabVIEWCli -CommandName Select-LVProvider -Times 1
                Remove-Variable -Name FallbackShell -Scope Script -ErrorAction SilentlyContinue
            } -ArgumentList $pwsh
        }
    }

    Context 'CLI suppression guards' {
        It 'skips invocation when COMPAREVI_NO_CLI_CAPTURE is set' {
            $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
            InModuleScope LabVIEWCli {
                param($shell)
                $script:Providers.Clear()
                $provider = New-TestLVProvider -Name 'Skip' -BinaryPath $shell -Supports { param($op) $op -eq 'CreateComparisonReport' } -ArgsBuilder {
                    @('-NoLogo','-Command',"Write-Output 'should-not-run'")
                }
                Register-LVProvider -Provider $provider -Confirm:$false
                Set-Item Env:COMPAREVI_NO_CLI_CAPTURE -Value '1'
                try {
                    Mock -ModuleName LabVIEWCli -CommandName Initialize-LabVIEWCliPidTracker -MockWith { throw 'tracker should not initialize' }
                    $result = Invoke-LVOperation -Operation 'CreateComparisonReport' -Params @{ vi1 = 'base.vi'; vi2 = 'head.vi' } -Provider 'Skip'
                    $result.skipped | Should -BeTrue
                    $result.skipReason | Should -Be 'COMPAREVI_NO_CLI_CAPTURE'
                    $result.ok | Should -BeTrue
                }
                finally {
                    Remove-Item Env:COMPAREVI_NO_CLI_CAPTURE -ErrorAction SilentlyContinue
                }
                Assert-MockCalled -ModuleName LabVIEWCli -CommandName Initialize-LabVIEWCliPidTracker -Times 0
            } -ArgumentList $pwsh
        }

        It 'suppresses invocation in git contexts and emits a warning when configured' {
            $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
            InModuleScope LabVIEWCli {
                param($shell)
                $script:Providers.Clear()
                $provider = New-TestLVProvider -Name 'GitGuard' -BinaryPath $shell -Supports { param($op) $op -eq 'CreateComparisonReport' } -ArgsBuilder {
                    @('-NoLogo','-Command',"Write-Output 'git-guard'")
                }
                Register-LVProvider -Provider $provider -Confirm:$false
                Set-Item Env:COMPAREVI_SUPPRESS_CLI_IN_GIT -Value '1'
                Set-Item Env:COMPAREVI_WARN_CLI_IN_GIT -Value '1'
                Set-Item Env:GIT_DIR -Value '.git'
                try {
                    Mock -ModuleName LabVIEWCli -CommandName Initialize-LabVIEWCliPidTracker -MockWith { throw 'git guard should skip before tracker' }
                    Mock -ModuleName LabVIEWCli -CommandName Touch-CompareCliSentinel -MockWith { throw 'git guard should not touch sentinel' }
                    Mock -ModuleName LabVIEWCli -CommandName Write-Warning -MockWith { param($Message) $script:lastGitWarning = $Message }

                    $result = Invoke-LVOperation -Operation 'CreateComparisonReport' -Params @{ vi1 = 'base.vi'; vi2 = 'head.vi' } -Provider 'GitGuard'
                    $result.skipped | Should -BeTrue
                    $result.skipReason | Should -Be 'git-context'
                    $result.ok | Should -BeTrue

                    Assert-MockCalled -ModuleName LabVIEWCli -CommandName Write-Warning -Times 1
                    Assert-MockCalled -ModuleName LabVIEWCli -CommandName Touch-CompareCliSentinel -Times 0
                    Assert-MockCalled -ModuleName LabVIEWCli -CommandName Initialize-LabVIEWCliPidTracker -Times 0
                    $script:lastGitWarning | Should -Match 'Git context'
                }
                finally {
                    Remove-Item Env:COMPAREVI_SUPPRESS_CLI_IN_GIT,Env:COMPAREVI_WARN_CLI_IN_GIT,Env:GIT_DIR -ErrorAction SilentlyContinue
                    Remove-Variable -Name lastGitWarning -Scope Script -ErrorAction SilentlyContinue
                }
            } -ArgumentList $pwsh
        }

        It 'warns but continues when git warning enabled without suppression' {
            $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
            InModuleScope LabVIEWCli {
                param($shell)
                $script:Providers.Clear()
                $provider = New-TestLVProvider -Name 'GitWarn' -BinaryPath $shell -Supports { param($op) $op -eq 'CreateComparisonReport' } -ArgsBuilder {
                    @('-NoLogo','-Command',"Write-Output 'git-warning-only'")
                }
                Register-LVProvider -Provider $provider -Confirm:$false
                Set-Item Env:COMPAREVI_WARN_CLI_IN_GIT -Value '1'
                Set-Item Env:GIT_DIR -Value '.git'
                try {
                    $script:gitWarnTrackerInit = 0
                    Mock -ModuleName LabVIEWCli -CommandName Set-LVHeadlessEnv -MockWith { @{} }
                    Mock -ModuleName LabVIEWCli -CommandName Restore-LVHeadlessEnv -MockWith {}
                    Mock -ModuleName LabVIEWCli -CommandName Initialize-LabVIEWCliPidTracker -MockWith { $script:gitWarnTrackerInit++ }
                    Mock -ModuleName LabVIEWCli -CommandName Finalize-LabVIEWCliPidTracker -MockWith {}
                    Mock -ModuleName LabVIEWCli -CommandName Write-Warning -MockWith { param($Message) $script:lastGitWarnOnly = $Message }

                    $result = Invoke-LVOperation -Operation 'CreateComparisonReport' -Params @{ vi1 = 'base.vi'; vi2 = 'head.vi'; reportPath = 'out.html' } -Provider 'GitWarn' -TimeoutSeconds 5
                    $wasSkipped = if ($result.PSObject.Properties['skipped']) { [bool]$result.skipped } else { $false }
                    $wasSkipped | Should -BeFalse
                    $result.exitCode | Should -Be 0
                    Assert-MockCalled -ModuleName LabVIEWCli -CommandName Initialize-LabVIEWCliPidTracker -Times 1
                    $script:lastGitWarnOnly | Should -Match 'Git context'
                }
                finally {
                    Remove-Item Env:COMPAREVI_WARN_CLI_IN_GIT,Env:GIT_DIR -ErrorAction SilentlyContinue
                    Remove-Variable -Name gitWarnTrackerInit -Scope Script -ErrorAction SilentlyContinue
                    Remove-Variable -Name lastGitWarnOnly -Scope Script -ErrorAction SilentlyContinue
                }
            } -ArgumentList $pwsh
        }

        It 'creates sentinel entries when TTL is configured but no prior file exists' {
            $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
            InModuleScope LabVIEWCli {
                param($shell)
                $script:Providers.Clear()
                $provider = New-TestLVProvider -Name 'TTLCreate' -BinaryPath $shell -Supports { param($op) $op -eq 'CreateComparisonReport' } -ArgsBuilder {
                    @('-NoLogo','-Command',"Write-Output 'ttl-create'")
                }
                Register-LVProvider -Provider $provider -Confirm:$false

                $vi1 = Join-Path $TestDrive 'ttl-empty-base.vi'
                $vi2 = Join-Path $TestDrive 'ttl-empty-head.vi'
                Set-Content -Path $vi1 -Value ''
                Set-Content -Path $vi2 -Value ''
                $sentinel = Join-Path $TestDrive 'ttl-empty.s'
                if (Test-Path $sentinel) { Remove-Item $sentinel -Force }

                Set-Item Env:COMPAREVI_CLI_SENTINEL_TTL -Value '90'
                try {
                    $script:lastTtlCreate = $null
                    Mock -ModuleName LabVIEWCli -CommandName Get-CompareCliSentinelPath -MockWith { param($Vi1,$Vi2,$ReportPath) $sentinel }
                    Mock -ModuleName LabVIEWCli -CommandName Touch-CompareCliSentinel -MockWith {
                        param($Vi1,$Vi2,$ReportPath)
                        $script:lastTtlCreate = @{
                            vi1    = $Vi1
                            vi2    = $Vi2
                            report = $ReportPath
                        }
                    }
                    Mock -ModuleName LabVIEWCli -CommandName Set-LVHeadlessEnv -MockWith { @{} }
                    Mock -ModuleName LabVIEWCli -CommandName Restore-LVHeadlessEnv -MockWith {}
                    Mock -ModuleName LabVIEWCli -CommandName Initialize-LabVIEWCliPidTracker -MockWith {}
                    Mock -ModuleName LabVIEWCli -CommandName Finalize-LabVIEWCliPidTracker -MockWith {}

                    $result = Invoke-LVOperation -Operation 'CreateComparisonReport' -Params @{ vi1 = $vi1; vi2 = $vi2; reportPath = 'ttl-empty.html' } -Provider 'TTLCreate'
                    $wasSkipped = if ($result.PSObject.Properties['skipped']) { [bool]$result.skipped } else { $false }
                    $wasSkipped | Should -BeFalse
                    $script:lastTtlCreate | Should -Not -BeNullOrEmpty
                    $script:lastTtlCreate.report | Should -Match 'ttl-empty.html'
                }
                finally {
                    Remove-Item Env:COMPAREVI_CLI_SENTINEL_TTL -ErrorAction SilentlyContinue
                    Remove-Variable -Name lastTtlCreate -Scope Script -ErrorAction SilentlyContinue
                }
            } -ArgumentList $pwsh
        }

        It 'skips invocation when comparison sentinel TTL is active' {
            $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
            InModuleScope LabVIEWCli {
                param($shell)
                $script:Providers.Clear()
                $provider = New-TestLVProvider -Name 'TTL' -BinaryPath $shell -Supports { param($op) $op -eq 'CreateComparisonReport' } -ArgsBuilder {
                    @('-NoLogo','-Command',"Write-Output 'ttl-guard'")
                }
                Register-LVProvider -Provider $provider -Confirm:$false

                $vi1 = Join-Path $TestDrive 'ttl-base.vi'
                $vi2 = Join-Path $TestDrive 'ttl-head.vi'
                Set-Content -Path $vi1 -Value ''
                Set-Content -Path $vi2 -Value ''
                $sentinel = Join-Path $TestDrive 'ttl-sentinel.s'
                Set-Content -Path $sentinel -Value ''
                (Get-Item $sentinel).LastWriteTimeUtc = [DateTime]::UtcNow

                Set-Item Env:COMPAREVI_CLI_SENTINEL_TTL -Value '180'
                try {
                    Mock -ModuleName LabVIEWCli -CommandName Get-CompareCliSentinelPath -MockWith { param($Vi1,$Vi2,$ReportPath) $sentinel }
                    Mock -ModuleName LabVIEWCli -CommandName Touch-CompareCliSentinel -MockWith { throw 'sentinel should not refresh' }
                    Mock -ModuleName LabVIEWCli -CommandName Initialize-LabVIEWCliPidTracker -MockWith { throw 'tracker should not initialize' }

                    $result = Invoke-LVOperation -Operation 'CreateComparisonReport' -Params @{ vi1 = $vi1; vi2 = $vi2; reportPath = 'ttl.html' } -Provider 'TTL'
                    $result.skipped | Should -BeTrue
                    $result.skipReason | Should -Be 'sentinel:180s'
                    Assert-MockCalled -ModuleName LabVIEWCli -CommandName Touch-CompareCliSentinel -Times 0
                    Assert-MockCalled -ModuleName LabVIEWCli -CommandName Initialize-LabVIEWCliPidTracker -Times 0
                }
                finally {
                    Remove-Item Env:COMPAREVI_CLI_SENTINEL_TTL -ErrorAction SilentlyContinue
                }
            } -ArgumentList $pwsh
        }

        It 'refreshes sentinel timestamp once TTL window expires' {
            $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
            InModuleScope LabVIEWCli {
                param($shell)
                $script:Providers.Clear()
                $provider = New-TestLVProvider -Name 'TTLRefresh' -BinaryPath $shell -Supports { param($op) $op -eq 'CreateComparisonReport' } -ArgsBuilder {
                    @('-NoLogo','-Command',"Write-Output 'ttl-refresh'")
                }
                Register-LVProvider -Provider $provider -Confirm:$false

                $vi1 = Join-Path $TestDrive 'ttl-base-old.vi'
                $vi2 = Join-Path $TestDrive 'ttl-head-old.vi'
                Set-Content -Path $vi1 -Value ''
                Set-Content -Path $vi2 -Value ''
                $sentinel = Join-Path $TestDrive 'ttl-sentinel-old.s'
                Set-Content -Path $sentinel -Value ''
                (Get-Item $sentinel).LastWriteTimeUtc = ([DateTime]::UtcNow).AddMinutes(-30)
                $expectedReport = [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path 'ttl-refresh.html'))

                Set-Item Env:COMPAREVI_CLI_SENTINEL_TTL -Value '60'
                try {
                    $script:lastTtlRefresh = $null
                    Mock -ModuleName LabVIEWCli -CommandName Get-CompareCliSentinelPath -MockWith { param($Vi1,$Vi2,$ReportPath) $sentinel }
                    Mock -ModuleName LabVIEWCli -CommandName Touch-CompareCliSentinel -MockWith {
                        param($Vi1,$Vi2,$ReportPath)
                        $script:lastTtlRefresh = @{
                            vi1    = $Vi1
                            vi2    = $Vi2
                            report = $ReportPath
                        }
                    }
                    Mock -ModuleName LabVIEWCli -CommandName Set-LVHeadlessEnv -MockWith { @{} }
                    Mock -ModuleName LabVIEWCli -CommandName Restore-LVHeadlessEnv -MockWith {}
                    Mock -ModuleName LabVIEWCli -CommandName Initialize-LabVIEWCliPidTracker -MockWith {}
                    Mock -ModuleName LabVIEWCli -CommandName Finalize-LabVIEWCliPidTracker -MockWith {}

                    $result = Invoke-LVOperation -Operation 'CreateComparisonReport' -Params @{ vi1 = $vi1; vi2 = $vi2; reportPath = 'ttl-refresh.html' } -Provider 'TTLRefresh'
                    $wasSkipped = if ($result.PSObject.Properties['skipped']) { [bool]$result.skipped } else { $false }
                    $wasSkipped | Should -BeFalse
                    $script:lastTtlRefresh.report | Should -Be $expectedReport
                }
                finally {
                    Remove-Item Env:COMPAREVI_CLI_SENTINEL_TTL -ErrorAction SilentlyContinue
                    Remove-Variable -Name lastTtlRefresh -Scope Script -ErrorAction SilentlyContinue
                }
            } -ArgumentList $pwsh
        }

        It 'touches the comparison sentinel after a successful run' {
            $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
            InModuleScope LabVIEWCli {
                param($shell)
                $script:Providers.Clear()
                $provider = New-TestLVProvider -Name 'Sentinel' -BinaryPath $shell -Supports { param($op) $op -eq 'CreateComparisonReport' } -ArgsBuilder {
                    @('-NoLogo','-Command',"Write-Output 'touch-sentinel'")
                }
                Register-LVProvider -Provider $provider -Confirm:$false
                Mock -ModuleName LabVIEWCli -CommandName Set-LVHeadlessEnv -MockWith { @{} }
                Mock -ModuleName LabVIEWCli -CommandName Restore-LVHeadlessEnv -MockWith {}
                Mock -ModuleName LabVIEWCli -CommandName Initialize-LabVIEWCliPidTracker -MockWith {}
                Mock -ModuleName LabVIEWCli -CommandName Finalize-LabVIEWCliPidTracker -MockWith {}
                Mock -ModuleName LabVIEWCli -CommandName Touch-CompareCliSentinel -MockWith {
                    param($Vi1,$Vi2,$ReportPath)
                    $script:lastSentinel = @{
                        vi1 = $Vi1
                        vi2 = $Vi2
                        report = $ReportPath
                    }
                }

                $base = Join-Path $TestDrive 'compare-base.vi'
                $head = Join-Path $TestDrive 'compare-head.vi'
                Set-Content -Path $base -Value ''
                Set-Content -Path $head -Value ''
                $expectedReport = [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path 'result.html'))

                $result = Invoke-LVOperation -Operation 'CreateComparisonReport' -Params @{ vi1 = $base; vi2 = $head; reportPath = 'result.html' } -Provider 'Sentinel'
                $result.ok | Should -BeTrue
                $script:lastSentinel | Should -Not -BeNullOrEmpty
                $script:lastSentinel.report | Should -Be $expectedReport
            } -ArgumentList $pwsh
        }

        It 'emits labview-cli:error finalize when Set-LVHeadlessEnv fails' {
            $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
            $trackerPath = Join-Path $TestDrive 'error-tracker' 'tracker.json'
            InModuleScope LabVIEWCli {
                param($shell,$tracker)
                $script:Providers.Clear()
                $provider = New-TestLVProvider -Name 'BrokenEnv' -BinaryPath $shell -Supports { param($op) $op -eq 'RunVI' } -ArgsBuilder {
                    param($op,$params) @('-NoLogo','-Command',"Write-Output 'noop'")
                }
                Register-LVProvider -Provider $provider -Confirm:$false
                $script:LabVIEWPidTrackerLoaded = $true
                $script:LabVIEWPidTrackerPath = $tracker
                $script:LabVIEWPidTrackerRelativePath = 'tests/results/_cli/error-tracker.json'
                Mock -ModuleName LabVIEWCli -CommandName Initialize-LabVIEWCliPidTracker -MockWith { }
                Mock -ModuleName LabVIEWCli -CommandName Set-LVHeadlessEnv -MockWith { throw 'headless-env-fail' }
                Mock -ModuleName LabVIEWCli -CommandName Restore-LVHeadlessEnv -MockWith { }
                $script:lastFinalizeError = $null
                Mock -ModuleName LabVIEWCli -CommandName Finalize-LabVIEWCliPidTracker -MockWith {
                    param(
                        $Source,
                        $Operation,
                        $Provider,
                        $ExitCode,
                        $TimedOut,
                        $CliArgs,
                        $ElapsedSeconds,
                        $Binary,
                        $ErrorMessage
                    )
                    $script:lastFinalizeError = @{
                        Source = $Source
                        Operation = $Operation
                        Provider = $Provider
                        ErrorMessage = $ErrorMessage
                    }
                }
                { Invoke-LVOperation -Operation 'RunVI' -Params @{ viPath = 'C:\broken.vi' } -Provider 'BrokenEnv' } | Should -Throw '*headless-env-fail*'
                $script:lastFinalizeError | Should -Not -BeNullOrEmpty
                $script:lastFinalizeError.Source | Should -Be 'labview-cli:error'
                $script:lastFinalizeError.Operation | Should -Be 'RunVI'
            } -ArgumentList $pwsh,$trackerPath
        }
    }

    Context 'Comparison suppression helpers' {
        It 'returns true when COMPAREVI_NO_CLI_CAPTURE is set' {
            Set-Item Env:COMPAREVI_NO_CLI_CAPTURE -Value '1'
            try {
                InModuleScope LabVIEWCli {
                    $reason = $null
                    $normalized = @{
                        vi1 = Join-Path $env:TEMP 'base.vi'
                        vi2 = Join-Path $env:TEMP 'head.vi'
                    }
                    Test-ShouldSuppressCliCompare -Operation 'CreateComparisonReport' -Normalized $normalized -Reason ([ref]$reason) | Should -BeTrue
                    $reason | Should -Be 'COMPAREVI_NO_CLI_CAPTURE'
                }
            }
            finally {
                Remove-Item Env:COMPAREVI_NO_CLI_CAPTURE -ErrorAction SilentlyContinue
            }
        }

        It 'uses sentinel TTLs to suppress duplicate comparisons' {
            $base = Join-Path $TestDrive 'cmp-base.vi'
            $head = Join-Path $TestDrive 'cmp-head.vi'
            Set-Content -Path $base -Value '' | Out-Null
            Set-Content -Path $head -Value '' | Out-Null
            $report = 'report.html'
            InModuleScope LabVIEWCli {
                param($baseVi,$headVi,$reportPath)
                $sentinel = Get-CompareCliSentinelPath -Vi1 $baseVi -Vi2 $headVi -ReportPath $reportPath
                New-Item -ItemType File -Path $sentinel -Force | Out-Null
                (Get-Item $sentinel).LastWriteTimeUtc = [DateTime]::UtcNow
            } -ArgumentList $base,$head,$report
            Set-Item Env:COMPAREVI_CLI_SENTINEL_TTL -Value '30'
            try {
                InModuleScope LabVIEWCli {
                    param($baseVi,$headVi,$reportPath)
                    $reason = $null
                    $normalized = @{
                        vi1 = $baseVi
                        vi2 = $headVi
                        reportPath = $reportPath
                    }
                    Test-ShouldSuppressCliCompare -Operation 'CreateComparisonReport' -Normalized $normalized -Reason ([ref]$reason) | Should -BeTrue
                    $reason | Should -Be 'sentinel:30s'
                } -ArgumentList $base,$head,$report
            }
            finally {
                Remove-Item Env:COMPAREVI_CLI_SENTINEL_TTL -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'Module utility functions' {
        It 'validates acceptable labels' {
            InModuleScope LabVIEWCli {
                Test-ValidLabel -Label 'alpha_1-2.3'
            }
        }

        It 'rejects invalid labels' {
            InModuleScope LabVIEWCli {
                { Test-ValidLabel -Label 'bad space' } | Should -Throw '*Invalid label*'
            }
        }

        It 'executes Invoke-WithTimeout successfully' {
            InModuleScope LabVIEWCli {
                $value = Invoke-WithTimeout -ScriptBlock { 1 + 1 } -TimeoutSec 5
                $value | Should -Be 2
            }
        }

        It 'throws when Invoke-WithTimeout exceeds the limit' {
            InModuleScope LabVIEWCli {
                { Invoke-WithTimeout -ScriptBlock { Start-Sleep -Seconds 2 } -TimeoutSec 0 } | Should -Throw '*timed out*'
            }
        }

        It 'Touch-CompareCliSentinel creates a sentinel file' {
            $base = Join-Path $TestDrive 'helper-base.vi'
            $head = Join-Path $TestDrive 'helper-head.vi'
            Set-Content -Path $base -Value '' | Out-Null
            Set-Content -Path $head -Value '' | Out-Null
            InModuleScope LabVIEWCli {
                param($vi1,$vi2)
                Touch-CompareCliSentinel -Vi1 $vi1 -Vi2 $vi2 -ReportPath 'helper-report.html'
                $sentinel = Get-CompareCliSentinelPath -Vi1 $vi1 -Vi2 $vi2 -ReportPath 'helper-report.html'
                Test-Path -LiteralPath $sentinel -PathType Leaf | Should -BeTrue
            } -ArgumentList $base,$head
        }

        It 'Set-LVHeadlessEnv and Restore-LVHeadlessEnv round-trip values' {
            $keys = @('LV_SUPPRESS_UI','LV_NO_ACTIVATE','LV_CURSOR_RESTORE','LV_IDLE_WAIT_SECONDS','LV_IDLE_MAX_WAIT_SECONDS')
            $originals = @{}
            foreach ($key in $keys) {
                $originals[$key] = [System.Environment]::GetEnvironmentVariable($key)
                [System.Environment]::SetEnvironmentVariable($key,$null)
            }
            [System.Environment]::SetEnvironmentVariable('LV_SUPPRESS_UI','orig')
            try {
                InModuleScope LabVIEWCli {
                    $guard = Set-LVHeadlessEnv
                    [System.Environment]::GetEnvironmentVariable('LV_SUPPRESS_UI') | Should -Be '1'
                    Restore-LVHeadlessEnv -Guard $guard
                }
                [System.Environment]::GetEnvironmentVariable('LV_SUPPRESS_UI') | Should -Be 'orig'
            }
            finally {
                foreach ($key in $keys) {
                    [System.Environment]::SetEnvironmentVariable($key,$originals[$key])
                }
            }
        }

        It 'Write-LVOperationEvent writes operation ndjson' {
            $repoRoot = Join-Path $TestDrive 'event-repo'
            New-Item -ItemType Directory -Force -Path (Join-Path $repoRoot 'tests') | Out-Null
            InModuleScope LabVIEWCli {
                param($root)
                $original = $script:RepoRoot
                $script:RepoRoot = $root
                try {
                    Write-LVOperationEvent -EventData @{ provider = 'Helper'; operation = 'RunVI'; exitCode = 0 }
                    $eventFile = Join-Path $root 'tests/results/_cli/operation-events.ndjson'
                    Test-Path -LiteralPath $eventFile -PathType Leaf | Should -BeTrue
                    $entry = (Get-Content -LiteralPath $eventFile -Raw).Trim() | ConvertFrom-Json
                    $entry.provider | Should -Be 'Helper'
                }
                finally {
                    $script:RepoRoot = $original
                }
            } -ArgumentList $repoRoot
        }

        It 'Get-LVOperationNames returns catalog entries' {
            InModuleScope LabVIEWCli {
                (Get-LVOperationNames) | Should -Contain 'RunVI'
            }
        }
    }

    Context 'PID tracker payload injection' {
        It 'attaches payload objects to Invoke-LVOperation results' {
            $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
            InModuleScope LabVIEWCli {
                param($shell)
                $script:Providers.Clear()
                $script:LabVIEWPidTrackerLoaded = $true
                $script:LabVIEWPidTrackerPath = Join-Path $env:TEMP 'labview-cli-tracker.json'
                $script:LabVIEWPidTrackerRelativePath = 'tests/results/_cli/labview-cli-tracker.json'
                $provider = New-TestLVProvider -Name 'Tracker' -BinaryPath $shell -Supports { param($op) $true } -ArgsBuilder {
                    @('-NoLogo','-Command',"Write-Output 'pid-tracker-run'")
                }
                Register-LVProvider -Provider $provider -Confirm:$false
                Mock -ModuleName LabVIEWCli -CommandName Resolve-LabVIEWCliPidTrackerPayload -MockWith {
                    @{
                        enabled = $true
                        path    = 'tracker.json'
                        final   = @{ exitCode = 0 }
                    }
                }
                Mock -ModuleName LabVIEWCli -CommandName Set-LVHeadlessEnv -MockWith { @{} }
                Mock -ModuleName LabVIEWCli -CommandName Restore-LVHeadlessEnv -MockWith {}
                Mock -ModuleName LabVIEWCli -CommandName Initialize-LabVIEWCliPidTracker -MockWith {}
                Mock -ModuleName LabVIEWCli -CommandName Finalize-LabVIEWCliPidTracker -MockWith {}

                $result = Invoke-LVOperation -Operation 'RunVI' -Params @{ viPath = 'C:\proj\tracker.vi' } -Provider 'Tracker'

                $result.labviewPidTracker | Should -Not -BeNullOrEmpty
                $result.labviewPidTracker.path | Should -Be 'tracker.json'
                Assert-MockCalled -ModuleName LabVIEWCli -CommandName Resolve-LabVIEWCliPidTrackerPayload -Times 1
            } -ArgumentList $pwsh
        }

        It 'adds payload to dictionary results' {
            InModuleScope LabVIEWCli {
                Mock -ModuleName LabVIEWCli -CommandName Resolve-LabVIEWCliPidTrackerPayload -MockWith {
                    @{ pid = 55; finalized = $true }
                }
                $result = [ordered]@{ provider = 'Alpha' }
                Add-LabVIEWCliPidTrackerToResult -Result $result
                $result['labviewPidTracker'].pid | Should -Be 55
            }
        }
    }

    Context 'Operational telemetry' {
        It 'writes operation events under tests/results/_cli' {
            $repoRoot = Join-Path $TestDrive 'lvcli-events'
            New-Item -ItemType Directory -Force -Path (Join-Path $repoRoot 'tests') | Out-Null
            InModuleScope LabVIEWCli {
                param($root)
                $originalRoot = $script:RepoRoot
                $script:RepoRoot = $root
                try {
                    Write-LVOperationEvent -EventData @{ provider = 'Alpha'; operation = 'RunVI'; exitCode = 0 }
                    $eventFile = Join-Path $root 'tests/results/_cli/operation-events.ndjson'
                    Test-Path -LiteralPath $eventFile | Should -BeTrue
                    $line = Get-Content -LiteralPath $eventFile -Raw
                    $entry = $line.Trim() | ConvertFrom-Json
                    $entry.provider | Should -Be 'Alpha'
                    $entry.operation | Should -Be 'RunVI'
                    $entry.timestamp | Should -Not -BeNullOrEmpty
                }
                finally {
                    $script:RepoRoot = $originalRoot
                }
            } -ArgumentList $repoRoot
        }
    }

    Context 'Invoke-LVCreateComparisonReport wrapper' {
        It 'propagates report path and arguments into normalized params' {
            $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
            InModuleScope LabVIEWCli {
                param($shell)
                $script:Providers.Clear()
                $provider = New-TestLVProvider -Name 'Wrapper' -BinaryPath $shell -Supports { param($op) $op -eq 'CreateComparisonReport' } -ArgsBuilder {
                    param($op,$params)
                    @('-NoLogo','-Command',"Write-Output 'wrapper-run'")
                }
                Register-LVProvider -Provider $provider -Confirm:$false
                Mock -ModuleName LabVIEWCli -CommandName Set-LVHeadlessEnv -MockWith { @{} }
                Mock -ModuleName LabVIEWCli -CommandName Restore-LVHeadlessEnv -MockWith {}
                Mock -ModuleName LabVIEWCli -CommandName Initialize-LabVIEWCliPidTracker -MockWith {}
                Mock -ModuleName LabVIEWCli -CommandName Finalize-LabVIEWCliPidTracker -MockWith {}

                $expectedReport = [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path 'custom-report.html'))
                $result = Invoke-LVCreateComparisonReport -BaseVi 'base.vi' -HeadVi 'head.vi' -ReportPath 'custom-report.html' -ReportType 'HTML' -Flags 'diffOnly' -Provider 'Wrapper' -TimeoutSeconds 5 -Preview
                $result.normalizedParams.reportPath | Should -Be $expectedReport
                $result.normalizedParams.reportType | Should -Be 'HTML'
                $result.normalizedParams.flags | Should -Contain 'diffOnly'
            } -ArgumentList $pwsh
        }
    }

    Context 'Wrapper commands' {
        It 'Invoke-LVRunVI normalizes arguments and switches' {
            $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
            InModuleScope LabVIEWCli {
                param($shell)
                $script:Providers.Clear()
                $provider = New-TestLVProvider -Name 'RunVI' -BinaryPath $shell -Supports { param($op) $op -eq 'RunVI' } -ArgsBuilder {
                    param($op,$params) @('-NoLogo','-Command',"Write-Output 'run-vi'")
                }
                Register-LVProvider -Provider $provider -Confirm:$false
                $expectedVi = [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path 'demo.vi'))
                $result = Invoke-LVRunVI -ViPath 'demo.vi' -Arguments 1,2 -ShowFrontPanel -AbortOnError -Provider 'RunVI' -Preview
                $result.normalizedParams.viPath | Should -Be $expectedVi
                $result.normalizedParams.showFP | Should -BeTrue
                $result.normalizedParams.abortOnError | Should -BeTrue
                $result.normalizedParams.arguments.Count | Should -Be 2
            } -ArgumentList $pwsh
        }

        It 'Invoke-LVRunVIAnalyzer passes report type and password' {
            $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
            InModuleScope LabVIEWCli {
                param($shell)
                $script:Providers.Clear()
                $provider = New-TestLVProvider -Name 'Analyzer' -BinaryPath $shell -Supports { param($op) $op -eq 'RunVIAnalyzer' } -ArgsBuilder {
                    param($op,$params) @('-NoLogo','-Command',"Write-Output 'vi-analyzer'")
                }
                Register-LVProvider -Provider $provider -Confirm:$false
                $expectedConfig = [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path 'config.cfg'))
                $expectedReport = [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path 'report.xml'))
                $result = Invoke-LVRunVIAnalyzer -ConfigPath 'config.cfg' -ReportPath 'report.xml' -ReportSaveType 'XML' -ConfigPassword 'secret' -Provider 'Analyzer' -Preview
                $result.normalizedParams.configPath | Should -Be $expectedConfig
                $result.normalizedParams.reportPath | Should -Be $expectedReport
                $result.normalizedParams.reportSaveType | Should -Be 'XML'
                $result.normalizedParams.configPassword | Should -Be 'secret'
            } -ArgumentList $pwsh
        }

        It 'Invoke-LVRunUnitTests normalizes junit path' {
            $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
            InModuleScope LabVIEWCli {
                param($shell)
                $script:Providers.Clear()
                $provider = New-TestLVProvider -Name 'UnitTests' -BinaryPath $shell -Supports { param($op) $op -eq 'RunUnitTests' } -ArgsBuilder {
                    param($op,$params) @('-NoLogo','-Command',"Write-Output 'unit-tests'")
                }
                Register-LVProvider -Provider $provider -Confirm:$false
                $expectedProject = [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path 'proj.lvproj'))
                $expectedJunit = [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path 'results.junit.xml'))
                $result = Invoke-LVRunUnitTests -ProjectPath 'proj.lvproj' -JUnitReportPath 'results.junit.xml' -Provider 'UnitTests' -Preview
                $result.normalizedParams.projectPath | Should -Be $expectedProject
                $result.normalizedParams.junitReportPath | Should -Be $expectedJunit
            } -ArgumentList $pwsh
        }

        It 'Invoke-LVMassCompile forwards optional parameters' {
            $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
            InModuleScope LabVIEWCli {
                param($shell)
                $script:Providers.Clear()
                $provider = New-TestLVProvider -Name 'MassCompile' -BinaryPath $shell -Supports { param($op) $op -eq 'MassCompile' } -ArgsBuilder {
                    param($op,$params) @('-NoLogo','-Command',"Write-Output 'mass-compile'")
                }
                Register-LVProvider -Provider $provider -Confirm:$false
                $expectedDir = [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path 'src'))
                $expectedLog = [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path 'mass.log'))
                $result = Invoke-LVMassCompile `
                    -DirectoryToCompile 'src' `
                    -MassCompileLogFile 'mass.log' `
                    -AppendToMassCompileLog `
                    -NumOfVIsToCache 42 `
                    -ReloadLVSBs `
                    -Provider 'MassCompile' `
                    -Preview
                $result.normalizedParams.directoryToCompile | Should -Be $expectedDir
                $result.normalizedParams.massCompileLogFile | Should -Be $expectedLog
                $result.normalizedParams.appendToMassCompileLog | Should -BeTrue
                $result.normalizedParams.numOfVIsToCache | Should -Be 42
                $result.normalizedParams.reloadLVSBs | Should -BeTrue
            } -ArgumentList $pwsh
        }

        It 'Invoke-LVExecuteBuildSpec normalizes target name' {
            $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
            InModuleScope LabVIEWCli {
                param($shell)
                $script:Providers.Clear()
                $provider = New-TestLVProvider -Name 'BuildSpec' -BinaryPath $shell -Supports { param($op) $op -eq 'ExecuteBuildSpec' } -ArgsBuilder {
                    param($op,$params) @('-NoLogo','-Command',"Write-Output 'build-spec'")
                }
                Register-LVProvider -Provider $provider -Confirm:$false
                $expectedProject = [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path 'project.lvproj'))
                $result = Invoke-LVExecuteBuildSpec -ProjectPath 'project.lvproj' -BuildSpecName 'IconEditorPackage' -TargetName 'MyTarget' -Provider 'BuildSpec' -Preview
                $result.normalizedParams.projectPath | Should -Be $expectedProject
                $result.normalizedParams.buildSpecName | Should -Be 'IconEditorPackage'
                $result.normalizedParams.targetName | Should -Be 'MyTarget'
            } -ArgumentList $pwsh
        }
    }
}
