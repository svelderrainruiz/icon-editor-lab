[CmdletBinding()]
param()
#Requires -Version 7.0

function script:New-TestGCliProvider {
    param(
        [string]$Name = 'GCli',
        [string]$Binary = (Join-Path $TestDrive 'gcli.exe'),
        [scriptblock]$Supports = { param($op) $true },
        [scriptblock]$ArgsBuilder = { param($op,$params) @('--op',$op) }
    )
    if ($Binary -and -not (Test-Path $Binary)) {
        New-Item -ItemType File -Path $Binary -Force | Out-Null
    }
    $provider = [pscustomobject]@{
        ScriptName   = $Name
        ScriptBinary = $Binary
    }
    $provider | Add-Member -MemberType ScriptMethod -Name Name -Value { $this.ScriptName } -Force
    $provider | Add-Member -MemberType ScriptMethod -Name ResolveBinaryPath -Value { $this.ScriptBinary } -Force
    $provider | Add-Member -MemberType ScriptMethod -Name Supports -Value $Supports -Force
    $provider | Add-Member -MemberType ScriptMethod -Name BuildArgs -Value $ArgsBuilder -Force
    return $provider
}

Describe 'g-cli provider helpers' -Tag 'Unit','Tools','GCli' {
    BeforeAll {
        $here = $PSScriptRoot
        if (-not $here -and $PSCommandPath) { $here = Split-Path -Parent $PSCommandPath }
        if (-not $here -and $MyInvocation.MyCommand.Path) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
        if (-not $here) { throw 'Unable to determine test root.' }
        $script:RepoRoot = (Resolve-Path (Join-Path $here '..\..\..')).Path
        $script:ModulePath = (Resolve-Path (Join-Path $script:RepoRoot 'src/tools/GCli.psm1')).Path
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
        }
    }

    AfterEach {
        InModuleScope GCli {
            if ($script:Providers) {
                $script:Providers.Clear()
            }
        }
    }

    AfterAll {
        if (Get-Module -Name GCli -ErrorAction SilentlyContinue) {
            Remove-Module GCli -Force -ErrorAction SilentlyContinue
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
                $provider = New-TestGCliProvider -Binary '' -Supports { $true }
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
    }
}
