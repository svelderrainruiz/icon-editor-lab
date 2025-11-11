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
    }
}
