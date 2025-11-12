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

function script:New-VipmProviderModuleContent {
    param(
        [string]$Name,
        [string]$Binary = 'C:\vipm.exe',
        [string]$Operation = 'build'
    )
@'
function New-VipmProvider {
    $provider = [pscustomobject]@{
        ProviderName = '__NAME__'
        ProviderBinary = '__BINARY__'
    }
    $provider | Add-Member -MemberType ScriptMethod -Name Name -Value { $this.ProviderName } -Force
    $provider | Add-Member -MemberType ScriptMethod -Name ResolveBinaryPath -Value { $this.ProviderBinary } -Force
    $provider | Add-Member -MemberType ScriptMethod -Name Supports -Value { param($op) $op -eq '__OP__' } -Force
    $provider | Add-Member -MemberType ScriptMethod -Name BuildArgs -Value { param($op,$params) @('--provider','__NAME__') } -Force
    return $provider
}
'@.Replace('__NAME__',$Name).Replace('__BINARY__',$Binary).Replace('__OP__',$Operation)
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
        if (Test-Path Env:ICON_EDITOR_VIPM_PROVIDER_ROOT) {
            Remove-Item Env:ICON_EDITOR_VIPM_PROVIDER_ROOT -ErrorAction SilentlyContinue
        }
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

        It 'throws when provider Name() returns whitespace' {
            $provider = New-TestVipmProvider
            $provider | Add-Member -MemberType ScriptMethod -Name Name -Value { '   ' } -Force
            { Register-VipmProvider -Provider $provider } | Should -Throw 'Provider registration failed: Name() returned empty.'
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
            { Get-VipmInvocation -Operation 'deploy' } | Should -Throw '*Viz*'
        }
    }

    Context 'Import-VipmProviderModules' {
        It 'registers providers discovered via manifests and fallback scripts' {
            $providerRoot = Join-Path $TestDrive 'vipm-providers'
            $manifestDir = Join-Path $providerRoot 'vipm-alpha'
            New-Item -ItemType Directory -Force -Path $manifestDir | Out-Null
            $manifestPath = Join-Path $manifestDir 'vipm-alpha.Provider.psd1'
            "@{ ModuleVersion = '1.0.0'; RootModule = 'Provider.psm1' }" | Set-Content -LiteralPath $manifestPath -Encoding utf8
            (New-VipmProviderModuleContent -Name 'Alpha' -Binary 'C:\alpha\vipm.exe') |
                Set-Content -LiteralPath (Join-Path $manifestDir 'Provider.psm1') -Encoding utf8

            $fallbackDir = Join-Path $providerRoot 'vipm-beta'
            New-Item -ItemType Directory -Force -Path $fallbackDir | Out-Null
            (New-VipmProviderModuleContent -Name 'Beta' -Binary 'C:\beta\vipm.exe') |
                Set-Content -LiteralPath (Join-Path $fallbackDir 'Provider.psm1') -Encoding utf8

            $resolvedRoot = (Resolve-Path $providerRoot).Path
            if (Get-Module -Name Vipm -ErrorAction SilentlyContinue) {
                Remove-Module Vipm -Force -ErrorAction SilentlyContinue
            }
            Import-Module -Name $script:ModulePath -Force
            Set-Item -Path Env:ICON_EDITOR_VIPM_PROVIDER_ROOT -Value $resolvedRoot

            InModuleScope Vipm {
                $script:Providers.Clear()
                Import-VipmProviderModules
            }

            $names = Get-VipmProviders | ForEach-Object { $_.Name() }
            $names | Should -Contain 'Alpha'
            $names | Should -Contain 'Beta'

            $invoke = Get-VipmInvocation -Operation 'build' -ProviderName 'beta'
            $invoke.Provider | Should -Be 'Beta'
            $invoke.Arguments | Should -Contain '--provider'
        }

        It 'emits warnings when provider modules fail to register' {
            $providerRoot = Join-Path $TestDrive 'vipm-invalid'
            $invalidDir = Join-Path $providerRoot 'vipm-bad'
            New-Item -ItemType Directory -Force -Path $invalidDir | Out-Null
            @'
function New-VipmProvider {
    return $null
}
'@ | Set-Content -LiteralPath (Join-Path $invalidDir 'Provider.psm1') -Encoding utf8

            $resolvedRoot = (Resolve-Path $providerRoot).Path
            if (Get-Module -Name Vipm -ErrorAction SilentlyContinue) {
                Remove-Module Vipm -Force -ErrorAction SilentlyContinue
            }
            Import-Module -Name $script:ModulePath -Force
            Set-Item -Path Env:ICON_EDITOR_VIPM_PROVIDER_ROOT -Value $resolvedRoot
            Mock -CommandName Write-Warning -ModuleName Vipm
            InModuleScope Vipm {
                $script:Providers.Clear()
                Import-VipmProviderModules
            }
            Assert-MockCalled -CommandName Write-Warning -ModuleName Vipm -Times 1
            (Get-VipmProviders | Measure-Object).Count | Should -Be 0
        }

        It 'returns early when override root does not exist' {
            $missingRoot = Join-Path $TestDrive 'no-such-dir'
            if (Get-Module -Name Vipm -ErrorAction SilentlyContinue) {
                Remove-Module Vipm -Force -ErrorAction SilentlyContinue
            }
            Import-Module -Name $script:ModulePath -Force
            Set-Item -Path Env:ICON_EDITOR_VIPM_PROVIDER_ROOT -Value $missingRoot
            InModuleScope Vipm {
                $script:Providers.Clear()
                Import-VipmProviderModules
            }
            (Get-VipmProviders | Measure-Object).Count | Should -Be 0
        }

        It 'continues registering providers when one module throws' {
            $providerRoot = Join-Path $TestDrive 'vipm-mixed'
            $throwDir = Join-Path $providerRoot 'vipm-throw'
            New-Item -ItemType Directory -Force -Path $throwDir | Out-Null
            @'
function New-VipmProvider {
    throw 'boom'
}
'@ | Set-Content -LiteralPath (Join-Path $throwDir 'Provider.psm1') -Encoding utf8

            $goodDir = Join-Path $providerRoot 'vipm-stable'
            New-Item -ItemType Directory -Force -Path $goodDir | Out-Null
            (New-VipmProviderModuleContent -Name 'Stable' -Binary 'C:\stable\vipm.exe') |
                Set-Content -LiteralPath (Join-Path $goodDir 'Provider.psm1') -Encoding utf8

            $resolvedRoot = (Resolve-Path $providerRoot).Path
            if (Get-Module -Name Vipm -ErrorAction SilentlyContinue) {
                Remove-Module Vipm -Force -ErrorAction SilentlyContinue
            }
            Import-Module -Name $script:ModulePath -Force
            Set-Item -Path Env:ICON_EDITOR_VIPM_PROVIDER_ROOT -Value $resolvedRoot

            Mock -CommandName Write-Warning -ModuleName Vipm
            InModuleScope Vipm {
                $script:Providers.Clear()
                Import-VipmProviderModules
            }
            Assert-MockCalled -CommandName Write-Warning -ModuleName Vipm -Times 1
            (Get-VipmProviderByName -Name 'stable') | Should -Not -BeNullOrEmpty
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
    Context 'Support utilities' {
        It 'handles Invoke-WithTimeout success and timeout cases' {
            InModuleScope Vipm {
                $jobId = 321
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
