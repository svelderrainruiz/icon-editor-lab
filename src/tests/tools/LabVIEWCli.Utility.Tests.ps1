[CmdletBinding()]
param()
#Requires -Version 7.0

Describe 'LabVIEWCli utility helpers' -Tag 'Unit','Tools','LabVIEWCli' {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
        $script:modulePath = (Resolve-Path (Join-Path $script:RepoRoot 'src\tools\LabVIEWCli.psm1')).Path
        if (Get-Module -Name LabVIEWCli -ErrorAction SilentlyContinue) {
            Remove-Module LabVIEWCli -Force -ErrorAction SilentlyContinue
        }
        $module = New-Module -Name LabVIEWCli -ScriptBlock {
            param($path)
            . $path
        } -ArgumentList $script:modulePath
        Import-Module $module -Force
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

            InModuleScope LabVIEWCli {
                Resolve-LVRepoRoot -StartPath $start -Confirm:$false | Should -Be (Resolve-Path $start).Path
            }
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
                InModuleScope LabVIEWCli {
                    Convert-ToAbsolutePath -PathValue $relative -Confirm:$false | Should -Be $expected
                }
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
