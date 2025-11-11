[CmdletBinding()]
param()
#Requires -Version 7.0

function script:New-TestVipmProvider {
    param(
        [string]$Name = 'Pkg',
        [string]$Binary = 'C:\vipm.exe',
        [scriptblock]$Supports = { param($op) $true },
        [scriptblock]$ArgsBuilder = { param($op,$params) @() }
    )
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

Describe 'VIPM tooling helpers' -Tag 'Unit','Tools','Vipm' {
    BeforeAll {
        $here = $PSScriptRoot
        if (-not $here -and $PSCommandPath) { $here = Split-Path -Parent $PSCommandPath }
        if (-not $here -and $MyInvocation.MyCommand.Path) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
        if (-not $here) { throw 'Unable to determine test root for VIPM specs.' }
        $script:RepoRoot = (Resolve-Path (Join-Path $here '..\..\..')).Path
        $script:ModulePath = (Resolve-Path (Join-Path $script:RepoRoot 'src/tools/Vipm.psm1')).Path
        Import-Module -Name $script:ModulePath -Force
    }

    AfterAll {
        if (Get-Module -Name Vipm -ErrorAction SilentlyContinue) {
            Remove-Module Vipm -Force -ErrorAction SilentlyContinue
        }
    }

    AfterEach {
        if (Get-Module -Name Vipm -ErrorAction SilentlyContinue) {
            Remove-Module Vipm -Force -ErrorAction SilentlyContinue
        }
        Import-Module -Name $script:ModulePath -Force
    }

    Context 'Register-VipmProvider' {
        It 'validates provider contract and registers case-insensitively' {
            $provider = New-TestVipmProvider -Supports { param($op) $op -eq 'build' } -ArgsBuilder { param($op,$params) @('--build',$params.Project) }
            Register-VipmProvider -Provider $provider
            $registered = Get-VipmProviderByName -Name 'pkg'
            $registered.Name() | Should -Be 'Pkg'
        }

        It 'throws when required methods are missing' {
            $provider = [pscustomobject]@{}
            { Register-VipmProvider -Provider $provider } | Should -Throw
        }
    }

    Context 'Get-VipmInvocation' {
        BeforeEach {
            $provider = New-TestVipmProvider -ArgsBuilder { param($op,$params) @('--op',$op) }
            Register-VipmProvider -Provider $provider
        }

        It 'returns invocation when provider supports operation' {
            $invoke = Get-VipmInvocation -Operation 'build' -Params @{ Project = 'icon.vipc' }
            $invoke.Binary | Should -Be 'C:\vipm.exe'
            $invoke.Provider | Should -Be 'Pkg'
            $invoke.Arguments[0] | Should -Be '--op'
        }

        It 'throws when no provider supports operation' {
            Remove-Module Vipm -Force -ErrorAction SilentlyContinue
            Import-Module -Name $script:ModulePath -Force
            { Get-VipmInvocation -Operation 'deploy' } | Should -Throw
        }

        It 'throws when provider returns empty binary path' {
            Remove-Module Vipm -Force -ErrorAction SilentlyContinue
            Import-Module -Name $script:ModulePath -Force
            $provider = New-TestVipmProvider -Binary '' -ArgsBuilder { param($op,$params) @() }
            Register-VipmProvider -Provider $provider
            { Get-VipmInvocation -Operation 'build' } | Should -Throw
        }

        It 'throws when ResolveBinaryPath raises an error' {
            Remove-Module Vipm -Force -ErrorAction SilentlyContinue
            Import-Module -Name $script:ModulePath -Force
            $provider = New-TestVipmProvider
            $provider | Add-Member -MemberType ScriptMethod -Name ResolveBinaryPath -Value { throw 'missing binary' } -Force
            Register-VipmProvider -Provider $provider
            { Get-VipmInvocation -Operation 'build' } | Should -Throw
        }

        It 'honors specific ProviderName filters' {
            Remove-Module Vipm -Force -ErrorAction SilentlyContinue
            Import-Module -Name $script:ModulePath -Force
            $alpha = New-TestVipmProvider -Name 'Alpha' -Supports { param($op) $op -eq 'package' } -ArgsBuilder { param($op,$params) @('--alpha') }
            $beta  = New-TestVipmProvider -Name 'Beta' -Supports { param($op) $op -eq 'package' } -ArgsBuilder { param($op,$params) @('--beta') }
            Register-VipmProvider -Provider $alpha
            Register-VipmProvider -Provider $beta
            $invoke = Get-VipmInvocation -Operation 'package' -ProviderName 'beta'
            $invoke.Provider | Should -Be 'Beta'
            $invoke.Arguments | Should -Contain '--beta'
        }

        It 'throws when requested provider does not exist' {
            Remove-Module Vipm -Force -ErrorAction SilentlyContinue
            Import-Module -Name $script:ModulePath -Force
            { Get-VipmInvocation -Operation 'build' -ProviderName 'ghost' } | Should -Throw
        }

        It 'returns empty args when provider BuildArgs returns null' {
            Remove-Module Vipm -Force -ErrorAction SilentlyContinue
            Import-Module -Name $script:ModulePath -Force
            $provider = New-TestVipmProvider -ArgsBuilder { param($op,$params) $null }
            Register-VipmProvider -Provider $provider
            $invoke = Get-VipmInvocation -Operation 'build'
            $invoke.Arguments | Should -HaveCount 0
        }

        It 'lists registered providers when none support the requested operation' {
            Remove-Module Vipm -Force -ErrorAction SilentlyContinue
            Import-Module -Name $script:ModulePath -Force
            $provider = New-TestVipmProvider -Name 'Viz' -Supports { $false }
            Register-VipmProvider -Provider $provider
            { Get-VipmInvocation -Operation 'deploy' } | Should -Throw
        }
    }

    Context 'Test-ValidLabel' {
        It 'accepts safe characters up to 64 chars' {
            { InModuleScope Vipm { Test-ValidLabel -Label 'Alpha-123_Release.1' } } | Should -Not -Throw
        }

        It 'rejects invalid symbols' {
            { InModuleScope Vipm { Test-ValidLabel -Label 'bad label!' } } | Should -Throw
        }
    }

}

