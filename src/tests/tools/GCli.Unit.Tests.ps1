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
            $moduleDir = Split-Path -Parent $script:ModulePath
            $providerRoot = Join-Path $moduleDir 'providers'
            $state = @{
                ProviderRoot  = $providerRoot
                AlphaDir      = Join-Path $providerRoot 'alpha'
                BetaDir       = Join-Path $providerRoot 'beta'
            }
            $state.AlphaManifest = Join-Path $state.AlphaDir 'alpha.Provider.psd1'
            $state.BetaFallback  = Join-Path $state.BetaDir 'Provider.psm1'
            $state.Directories   = @(
                [pscustomobject]@{ FullName = $state.AlphaDir; Name = 'alpha' },
                [pscustomobject]@{ FullName = $state.BetaDir;  Name = 'beta'  }
            )
            $global:__GCliImportTestState = $state

            Mock -CommandName Test-Path -ModuleName GCli -MockWith {
                param($LiteralPath,[Microsoft.PowerShell.Commands.TestPathType]$PathType)
                $state = $global:__GCliImportTestState
                if ($LiteralPath -eq $state.ProviderRoot) { return $true }
                if ($LiteralPath -eq $state.AlphaManifest) { return $true }
                if ($LiteralPath -eq (Join-Path $state.BetaDir 'beta.Provider.psd1')) { return $false }
                if ($LiteralPath -eq $state.BetaFallback) { return $true }
                return $false
            }

            Mock -CommandName Get-ChildItem -ModuleName GCli -MockWith {
                param($Path,[switch]$Directory)
                $state = $global:__GCliImportTestState
                $state.Directories
            }

            Mock -CommandName Import-Module -ModuleName GCli -MockWith {
                param($Name,[switch]$Force,[switch]$PassThru)
                $state = $global:__GCliImportTestState
                if ($Name -eq $state.AlphaManifest) { return [pscustomobject]@{ Name = 'AlphaManifest' } }
                if ($Name -eq $state.BetaFallback) { return [pscustomobject]@{ Name = 'BetaFallback' } }
                throw "Unexpected module path: $Name"
            }

            Mock -CommandName Get-Command -ModuleName GCli -MockWith {
                param($Name,$Module,$ErrorAction)
                switch ($Module) {
                    'AlphaManifest' { return { New-TestGCliProvider -Name 'alpha' -Manager 'vipm' -Supports { param($op) $op -eq 'build' } } }
                    'BetaFallback'  { return { New-TestGCliProvider -Name 'beta'  -Manager 'nipm' -Supports { param($op) $op -eq 'deploy' } } }
                    default { throw "Unexpected module $Module" }
                }
            }

            try {
                InModuleScope GCli {
                    $script:Providers.Clear()
                    Import-GCliProviderModules
                    (Get-GCliProviders | ForEach-Object { $_.Name() }) | Should -Contain 'alpha'
                    (Get-GCliProviders | ForEach-Object { $_.Name() }) | Should -Contain 'beta'
                    (Get-GCliProviders -Manager 'nipm').Name() | Should -Be 'beta'
                }
            } finally {
                $global:__GCliImportTestState = $null
            }
        }

        It 'writes a warning when provider initialization fails' {
            $moduleDir = Split-Path -Parent $script:ModulePath
            $providerRoot = Join-Path $moduleDir 'providers'
            $invalidDir = Join-Path $providerRoot 'invalid'
            $state = @{
                ProviderRoot    = $providerRoot
                InvalidManifest = Join-Path $invalidDir 'invalid.Provider.psd1'
                InvalidFallback = Join-Path $invalidDir 'Provider.psm1'
                Directories     = @([pscustomobject]@{ FullName = $invalidDir; Name = 'invalid' })
            }
            $global:__GCliImportTestState = $state

            Mock -CommandName Test-Path -ModuleName GCli -MockWith {
                param($LiteralPath,[Microsoft.PowerShell.Commands.TestPathType]$PathType)
                $state = $global:__GCliImportTestState
                if ($LiteralPath -eq $state.ProviderRoot) { return $true }
                if ($LiteralPath -eq $state.InvalidManifest) { return $false }
                if ($LiteralPath -eq $state.InvalidFallback) { return $true }
                return $false
            }

            Mock -CommandName Get-ChildItem -ModuleName GCli -MockWith {
                param($Path,[switch]$Directory)
                $state = $global:__GCliImportTestState
                $state.Directories
            }

            Mock -CommandName Import-Module -ModuleName GCli -MockWith {
                param($Name,[switch]$Force,[switch]$PassThru)
                $state = $global:__GCliImportTestState
                if ($Name -eq $state.InvalidFallback) { return [pscustomobject]@{ Name = 'InvalidProvider' } }
                throw "Unexpected module path: $Name"
            }

            Mock -CommandName Get-Command -ModuleName GCli -MockWith {
                param($Name,$Module,$ErrorAction)
                if ($Module -eq 'InvalidProvider') { return { return $null } }
                throw "Unexpected module $Module"
            }

            Mock -CommandName Write-Warning -ModuleName GCli

            try {
                InModuleScope GCli {
                    $script:Providers.Clear()
                    Import-GCliProviderModules
                    Assert-MockCalled -CommandName Write-Warning -ModuleName GCli -Times 1
                    (Get-GCliProviders | Measure-Object).Count | Should -Be 0
                }
            } finally {
                $global:__GCliImportTestState = $null
            }
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

