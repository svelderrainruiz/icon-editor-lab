[CmdletBinding()]
param()
#Requires -Version 7.0

function script:New-TestGCliProvider {
    param(
        [string]$Name = 'GCli',
        [string]$Binary = (Join-Path $TestDrive 'gcli.exe'),
        [scriptblock]$Supports = { param($op) $true },
        [scriptblock]$ArgsBuilder = { param($op,$params) @('--op',$op) },
        [string]$Manager = 'vipm'
    )
    if ($Binary -and -not (Test-Path $Binary)) {
        New-Item -ItemType File -Path $Binary -Force | Out-Null
    }
    $provider = [pscustomobject]@{
        ScriptName   = $Name
        ScriptBinary = $Binary
        ScriptManager= $Manager
    }
    $provider | Add-Member -MemberType ScriptMethod -Name Name -Value { $this.ScriptName } -Force
    $provider | Add-Member -MemberType ScriptMethod -Name ResolveBinaryPath -Value { $this.ScriptBinary } -Force
    $provider | Add-Member -MemberType ScriptMethod -Name Supports -Value $Supports -Force
    $provider | Add-Member -MemberType ScriptMethod -Name BuildArgs -Value $ArgsBuilder -Force
    $provider | Add-Member -MemberType ScriptMethod -Name Manager -Value { $this.ScriptManager } -Force
    return $provider
}

function script:New-GCliProviderModuleContent {
    param(
        [string]$Name,
        [string]$Binary = 'C:\tools\g-cli.exe',
        [string]$Manager = 'vipm',
        [string]$Operation = 'build'
    )
@'
function New-GCliProvider {
    $provider = [pscustomobject]@{
        ProviderName    = '__NAME__'
        ProviderBinary  = '__BINARY__'
        ProviderManager = '__MANAGER__'
    }
    $provider | Add-Member -MemberType ScriptMethod -Name Name -Value { $this.ProviderName } -Force
    $provider | Add-Member -MemberType ScriptMethod -Name ResolveBinaryPath -Value { $this.ProviderBinary } -Force
    $provider | Add-Member -MemberType ScriptMethod -Name Supports -Value { param($op) $op -eq '__OP__' } -Force
    $provider | Add-Member -MemberType ScriptMethod -Name BuildArgs -Value { param($op,$params) @('--provider','__NAME__') } -Force
    $provider | Add-Member -MemberType ScriptMethod -Name Manager -Value { $this.ProviderManager } -Force
    return $provider
}
'@.Replace('__NAME__',$Name).Replace('__BINARY__',$Binary).Replace('__MANAGER__',$Manager).Replace('__OP__',$Operation)
}

Describe 'g-cli provider helpers' -Tag 'Unit','Tools','GCli' {
    BeforeAll {
        $here = $PSScriptRoot
        if (-not $here -and $PSCommandPath) { $here = Split-Path -Parent $PSCommandPath }
        if (-not $here -and $MyInvocation.MyCommand.Path) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
        if (-not $here) { throw 'Unable to determine test root.' }
        $script:RepoRoot = (Resolve-Path (Join-Path $here '..\..\..')).Path
        $script:ModulePath = (Resolve-Path (Join-Path $script:RepoRoot 'src/tools/GCli.psm1')).Path
        $script:InitialProviderRoot = Join-Path $TestDrive 'gcli-initial-empty'
        New-Item -ItemType Directory -Force -Path $script:InitialProviderRoot | Out-Null
        Set-Item -Path Env:ICON_EDITOR_GCLI_PROVIDER_ROOT -Value $script:InitialProviderRoot
        if (Get-Module -Name GCli -ErrorAction SilentlyContinue) {
            Remove-Module GCli -Force -ErrorAction SilentlyContinue
        }
        Import-Module -Name $script:ModulePath -Force
    }

    BeforeEach {
        InModuleScope GCli {
            if ($script:Providers) {
                $script:Providers.Clear()
            }
            $script:ProvidersPopulated = $false
        }
        if ($script:InitialProviderRoot) {
            Set-Item -Path Env:ICON_EDITOR_GCLI_PROVIDER_ROOT -Value $script:InitialProviderRoot
        }
    }

    AfterEach {
        InModuleScope GCli {
            if ($script:Providers) {
                $script:Providers.Clear()
            }
            $script:ProvidersPopulated = $false
        }
        if (Test-Path Env:ICON_EDITOR_GCLI_PROVIDER_ROOT) {
            Remove-Item Env:ICON_EDITOR_GCLI_PROVIDER_ROOT -ErrorAction SilentlyContinue
        }
    }

    AfterAll {
        if (Get-Module -Name GCli -ErrorAction SilentlyContinue) {
            Remove-Module GCli -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path Env:ICON_EDITOR_GCLI_PROVIDER_ROOT) {
            Remove-Item Env:ICON_EDITOR_GCLI_PROVIDER_ROOT -ErrorAction SilentlyContinue
        }
    }

    Context 'Register-GCliProvider' {
        It 'stores providers case-insensitively and exposes lookup helpers' {
            InModuleScope GCli {
                $provider = New-TestGCliProvider -Name 'CLI'
                Register-GCliProvider -Provider $provider -Confirm:$false
                (Get-GCliProviderByName -Name 'cli').Name() | Should -Be 'CLI'
                (Get-GCliProviders | Measure-Object).Count | Should -Be 1
            }
        }

        It 'throws when provider contract is incomplete' {
            InModuleScope GCli {
                { Register-GCliProvider -Provider ([pscustomobject]@{ }) -Confirm:$false } | Should -Throw '*missing required method*'
            }
        }

        It 'rejects providers whose Name() returns whitespace' {
            InModuleScope GCli {
                $provider = New-TestGCliProvider
                $provider | Add-Member -MemberType ScriptMethod -Name Name -Value { '   ' } -Force
                { Register-GCliProvider -Provider $provider -Confirm:$false } | Should -Throw 'Provider registration failed: Name() returned empty.'
            }
        }

        It 'allows filtering providers by manager' {
            InModuleScope GCli {
                $vipmProvider = New-TestGCliProvider -Name 'Vipm' -Manager 'vipm'
                $nipmProvider = New-TestGCliProvider -Name 'Nipm' -Manager 'nipm'
                Register-GCliProvider -Provider $vipmProvider -Confirm:$false
                Register-GCliProvider -Provider $nipmProvider -Confirm:$false
                (Get-GCliProviders -Manager 'nipm').Name() | Should -Be 'Nipm'
                (Get-GCliProviders -Manager 'vipm').Name() | Should -Be 'Vipm'
            }
        }

        It 'prefers provider Manager() output over explicit parameter' {
            InModuleScope GCli {
                $provider = New-TestGCliProvider -Name 'Custom' -Manager 'nipm'
                Register-GCliProvider -Provider $provider -Manager 'vipm' -Confirm:$false
                (Get-GCliProviders -Manager 'nipm').Name() | Should -Be 'Custom'
                (Get-GCliProviders -Manager 'vipm' | Measure-Object).Count | Should -Be 0
            }
        }
    }

    Context 'Import-GCliProviderModules' {
        It 'registers providers discovered via manifest and fallback scripts' {
            $providerRoot = Join-Path $TestDrive 'gcli-providers'
            $manifestDir = Join-Path $providerRoot 'gcli-alpha'
            New-Item -ItemType Directory -Force -Path $manifestDir | Out-Null
            "@{ ModuleVersion = '1.0.0'; RootModule = 'Provider.psm1' }" |
                Set-Content -LiteralPath (Join-Path $manifestDir 'gcli-alpha.Provider.psd1') -Encoding utf8
            (New-GCliProviderModuleContent -Name 'Alpha' -Manager 'vipm' -Operation 'build') |
                Set-Content -LiteralPath (Join-Path $manifestDir 'Provider.psm1') -Encoding utf8

            $fallbackDir = Join-Path $providerRoot 'gcli-beta'
            New-Item -ItemType Directory -Force -Path $fallbackDir | Out-Null
            (New-GCliProviderModuleContent -Name 'Beta' -Manager 'nipm' -Operation 'deploy') |
                Set-Content -LiteralPath (Join-Path $fallbackDir 'Provider.psm1') -Encoding utf8

            $resolvedRoot = (Resolve-Path $providerRoot).Path
            Set-Item -Path Env:ICON_EDITOR_GCLI_PROVIDER_ROOT -Value $resolvedRoot
            InModuleScope GCli {
                $script:Providers.Clear()
                $script:ProvidersPopulated = $false
                Import-GCliProviderModules
            }

            $names = Get-GCliProviders | ForEach-Object { $_.Name() }
            $names | Should -Contain 'Alpha'
            $names | Should -Contain 'Beta'

            $invoke = Get-GCliInvocation -Operation 'deploy' -Manager 'nipm'
            $invoke.Provider | Should -Be 'Beta'
            $invoke.Arguments | Should -Contain '--provider'
        }

        It 'writes a warning when provider initialization fails' {
            $providerRoot = Join-Path $TestDrive 'gcli-invalid'
            $invalidDir = Join-Path $providerRoot 'gcli-bad'
            New-Item -ItemType Directory -Force -Path $invalidDir | Out-Null
@'
function New-GCliProvider { return $null }
'@ | Set-Content -LiteralPath (Join-Path $invalidDir 'Provider.psm1') -Encoding utf8

            $resolvedRoot = (Resolve-Path $providerRoot).Path
            Set-Item -Path Env:ICON_EDITOR_GCLI_PROVIDER_ROOT -Value $resolvedRoot
            Mock -CommandName Write-Warning -ModuleName GCli

            InModuleScope GCli {
                $script:Providers.Clear()
                $script:ProvidersPopulated = $false
                Import-GCliProviderModules
            }
            Assert-MockCalled -CommandName Write-Warning -ModuleName GCli -Times 1
            (Get-GCliProviders | Measure-Object).Count | Should -Be 0
        }

        It 'returns early when override root does not exist' {
            $missingRoot = Join-Path $TestDrive 'does-not-exist'
            Set-Item -Path Env:ICON_EDITOR_GCLI_PROVIDER_ROOT -Value $missingRoot
            InModuleScope GCli {
                $script:Providers.Clear()
                $script:ProvidersPopulated = $false
                Import-GCliProviderModules
                (Get-GCliProviders | Measure-Object).Count | Should -Be 0
            }
        }

        It 'continues registering providers when one module throws' {
            $providerRoot = Join-Path $TestDrive 'gcli-mixed'
            $throwDir = Join-Path $providerRoot 'gcli-throw'
            New-Item -ItemType Directory -Force -Path $throwDir | Out-Null
@'
function New-GCliProvider { throw "boom" }
'@ | Set-Content -LiteralPath (Join-Path $throwDir 'Provider.psm1') -Encoding utf8

            $goodDir = Join-Path $providerRoot 'gcli-good'
            New-Item -ItemType Directory -Force -Path $goodDir | Out-Null
            (New-GCliProviderModuleContent -Name 'Stable' -Manager 'vipm') |
                Set-Content -LiteralPath (Join-Path $goodDir 'Provider.psm1') -Encoding utf8

            $resolvedRoot = (Resolve-Path $providerRoot).Path
            Set-Item -Path Env:ICON_EDITOR_GCLI_PROVIDER_ROOT -Value $resolvedRoot
            Mock -CommandName Write-Warning -ModuleName GCli

            InModuleScope GCli {
                $script:Providers.Clear()
                $script:ProvidersPopulated = $false
                Import-GCliProviderModules
            }
            Assert-MockCalled -CommandName Write-Warning -ModuleName GCli -Times 1
            (Get-GCliProviderByName -Name 'stable') | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Provider loading guard' {
        It 'imports providers when cache is empty' {
            InModuleScope GCli {
                $script:Providers.Clear()
                $script:ProvidersPopulated = $false
            }
            Mock -CommandName Import-GCliProviderModules -ModuleName GCli -MockWith {
                InModuleScope GCli {
                    $provider = New-TestGCliProvider -Name 'Auto' -Binary (Join-Path $env:TEMP 'auto-gcli.exe')
                    Register-GCliProvider -Provider $provider -Confirm:$false
                    $script:ProvidersPopulated = $true
                }
            }
            InModuleScope GCli {
                (Get-GCliProviders | ForEach-Object { $_.Name() }) | Should -Contain 'Auto'
            }
            Assert-MockCalled -CommandName Import-GCliProviderModules -ModuleName GCli -Times 1
        }

        It 'skips import when providers already populated' {
            InModuleScope GCli {
                $script:Providers.Clear()
                $script:ProvidersPopulated = $true
            }
            Mock -CommandName Import-GCliProviderModules -ModuleName GCli -MockWith {
                throw 'Import should not occur'
            }
            InModuleScope GCli {
                (Get-GCliProviders | Measure-Object).Count | Should -Be 0
            }
            Assert-MockCalled -CommandName Import-GCliProviderModules -ModuleName GCli -Times 0
        }
    }
    Context 'Get-GCliInvocation' {
        It 'builds command invocation for registered providers' {
            InModuleScope GCli {
                $provider = New-TestGCliProvider -Name 'Build' -Binary (Join-Path $TestDrive 'gcli.exe') -ArgsBuilder {
                    param($op,$params)
                    @('--build',$params.Project)
                }
                Register-GCliProvider -Provider $provider -Confirm:$false
                $invoke = Get-GCliInvocation -Operation 'build' -Params @{ Project = 'icon.gvi' }
                $invoke.Provider | Should -Be 'Build'
                $invoke.Binary | Should -Match 'gcli\.exe$'
                $invoke.Arguments | Should -Contain '--build'
                $invoke.Arguments | Should -Contain 'icon.gvi'
            }
        }

        It 'throws when provider name is unknown' {
            InModuleScope GCli {
                { Get-GCliInvocation -Operation 'build' -ProviderName 'missing' } | Should -Throw '*not registered*'
            }
        }

        It 'throws when provider ResolveBinaryPath returns empty' {
            InModuleScope GCli {
                $provider = New-TestGCliProvider
                $provider | Add-Member -MemberType ScriptMethod -Name ResolveBinaryPath -Value { '' } -Force
                Register-GCliProvider -Provider $provider -Confirm:$false
                { Get-GCliInvocation -Operation 'build' } | Should -Throw '*failed to resolve g-cli binary path*'
            }
        }

        It 'fails when no providers support an operation' {
            InModuleScope GCli {
                $provider = New-TestGCliProvider -Name 'NoOp' -Supports { $false }
                Register-GCliProvider -Provider $provider -Confirm:$false
                { Get-GCliInvocation -Operation 'deploy' } | Should -Throw '*No g-cli provider registered*'
            }
        }

        It 'filters providers by manager when requested' {
            InModuleScope GCli {
                $vipmProvider = New-TestGCliProvider -Name 'Vipm' -Manager 'vipm' -Supports { param($op) $op -eq 'build' }
                $nipmProvider = New-TestGCliProvider -Name 'Nipm' -Manager 'nipm' -Supports { param($op) $op -eq 'deploy' }
                Register-GCliProvider -Provider $vipmProvider -Confirm:$false
                Register-GCliProvider -Provider $nipmProvider -Confirm:$false
                $invoke = Get-GCliInvocation -Operation 'deploy' -Manager 'nipm'
                $invoke.Provider | Should -Be 'Nipm'
                { Get-GCliInvocation -Operation 'build' -Manager 'nipm' } | Should -Throw '*No g-cli provider registered*'
            }
        }

        It 'resolves provider by name and manager' {
            InModuleScope GCli {
                $vipmProvider = New-TestGCliProvider -Name 'VipmOnly' -Manager 'vipm'
                Register-GCliProvider -Provider $vipmProvider -Confirm:$false
                $invoke = Get-GCliInvocation -Operation 'build' -ProviderName 'VipmOnly' -Manager 'vipm'
                $invoke.Provider | Should -Be 'VipmOnly'
            }
        }

        It 'returns empty arguments when provider BuildArgs outputs null' {
            InModuleScope GCli {
                $provider = New-TestGCliProvider -Name 'NullArgs' -ArgsBuilder { param($op,$params) $null }
                Register-GCliProvider -Provider $provider -Confirm:$false
                $invoke = Get-GCliInvocation -Operation 'build'
                $invoke.Arguments | Should -HaveCount 0
            }
        }
    }

    Context 'Support utilities' {
        It 'validates labels using Test-ValidLabel' {
            InModuleScope GCli {
                { Test-ValidLabel -Label 'alpha-123_release.1' } | Should -Not -Throw
                { Test-ValidLabel -Label 'bad label!' } | Should -Throw '*Invalid label*'
            }
        }

        It 'handles Invoke-WithTimeout success and timeout cases' {
            InModuleScope GCli {
                $jobId = 777
                Mock -CommandName Start-Job -MockWith {
                    param([scriptblock]$ScriptBlock)
                    & $ScriptBlock | Out-Null
                    return $jobId
                }
                Mock -CommandName Wait-Job -MockWith {
                    param($Argument,[Parameter(ValueFromRemainingArguments=$true)][object[]]$Ignore)
                    $true
                }
                Mock -CommandName Receive-Job -MockWith {
                    param($Argument,[Parameter(ValueFromRemainingArguments=$true)][object[]]$Ignore)
                    'done'
                }
                Invoke-WithTimeout -ScriptBlock { 'ok' } -TimeoutSec 5 | Should -Be 'done'

                Mock -CommandName Wait-Job -MockWith {
                    param($Argument,[Parameter(ValueFromRemainingArguments=$true)][object[]]$Ignore)
                    $false
                }
                Mock -CommandName Stop-Job -MockWith {
                    param($Argument,[Parameter(ValueFromRemainingArguments=$true)][object[]]$Ignore)
                }
                { Invoke-WithTimeout -ScriptBlock { Start-Sleep -Milliseconds 5 } -TimeoutSec 0 } | Should -Throw '*timed out*'
            }
        }
    }
}

