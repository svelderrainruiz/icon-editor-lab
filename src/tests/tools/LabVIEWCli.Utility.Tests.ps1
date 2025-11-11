[CmdletBinding()]
param()
#Requires -Version 7.0

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
}
