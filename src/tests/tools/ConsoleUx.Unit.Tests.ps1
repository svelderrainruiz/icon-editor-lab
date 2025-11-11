[CmdletBinding()]
param()
#Requires -Version 7.0

Describe 'ConsoleUx diagnostics helpers' -Tag 'Unit','Tools','ConsoleUx' {
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
        $script:modulePath = (Resolve-Path (Join-Path $script:RepoRoot 'src/tools/ConsoleUx.psm1')).Path
        if (Get-Module -Name ConsoleUx -ErrorAction SilentlyContinue) {
            Remove-Module ConsoleUx -Force -ErrorAction SilentlyContinue
        }
        Import-Module -Name $script:modulePath -Force -ErrorAction Stop
    }

    AfterAll {
        if (Get-Module -Name ConsoleUx -ErrorAction SilentlyContinue) {
            Remove-Module ConsoleUx -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Get-DxLevel' {
        BeforeEach {
            $script:originalDx = $env:DX_CONSOLE_LEVEL
        }

        AfterEach {
            if ($null -eq $script:originalDx) {
                Remove-Item Env:DX_CONSOLE_LEVEL -ErrorAction SilentlyContinue
            } else {
                $env:DX_CONSOLE_LEVEL = $script:originalDx
            }
        }

        It 'defaults to normal when environment is not set' {
            Remove-Item Env:DX_CONSOLE_LEVEL -ErrorAction SilentlyContinue
            InModuleScope ConsoleUx {
                Get-DxLevel | Should -Be 'normal'
            }
        }

        It 'returns explicit override when provided' {
            $env:DX_CONSOLE_LEVEL = 'debug'
            InModuleScope ConsoleUx {
                Get-DxLevel -Override concisE | Should -Be 'concise'
            }
        }

        It 'normalizes environment values' {
            $env:DX_CONSOLE_LEVEL = 'Dbg'
            InModuleScope ConsoleUx {
                Get-DxLevel | Should -Be 'debug'
            }
        }
    }

    Context 'Test-DxAtLeast ranking' {
        It 'returns true when level is at least requested threshold' {
            InModuleScope ConsoleUx {
                Test-DxAtLeast -Level 'debug' -AtLeast 'normal' | Should -BeTrue
            }
        }

        It 'returns false when level is below threshold' {
            InModuleScope ConsoleUx {
                Test-DxAtLeast -Level 'concise' -AtLeast 'detailed' | Should -BeFalse
            }
        }
    }

    Context 'Write-Dx output selection' {
        It 'emits info lines when console level allows it' {
            Mock -CommandName Write-Host -ModuleName ConsoleUx {}
            Mock -CommandName Write-Warning -ModuleName ConsoleUx {}
            Mock -CommandName Write-Error -ModuleName ConsoleUx {}

            InModuleScope ConsoleUx {
                Write-Dx -Message 'hello world' -ConsoleLevel 'normal'
            }

            Assert-MockCalled Write-Host -ModuleName ConsoleUx -Times 1
            Assert-MockCalled Write-Warning -ModuleName ConsoleUx -Times 0
            Assert-MockCalled Write-Error -ModuleName ConsoleUx -Times 0
        }

        It 'suppresses info when console level is quiet but still surfaces warnings' {
            Mock -CommandName Write-Host -ModuleName ConsoleUx {}
            Mock -CommandName Write-Warning -ModuleName ConsoleUx {}

            InModuleScope ConsoleUx {
                Write-Dx -Message 'warn only' -Level 'warn' -ConsoleLevel 'quiet'
            }

            Assert-MockCalled Write-Host -ModuleName ConsoleUx -Times 0
            Assert-MockCalled Write-Warning -ModuleName ConsoleUx -Times 1 -ParameterFilter { $Message -eq 'warn only' }
        }
    }

    Context 'Write-DxKV formatting' {
        It 'sorts keys and emits concise output' {
            Mock -CommandName Write-Host -ModuleName ConsoleUx {}

            InModuleScope ConsoleUx {
                Write-DxKV -Data @{ bravo = 2; alpha = 1; empty = '' } -ConsoleLevel 'normal'
            }

            Assert-MockCalled Write-Host -ModuleName ConsoleUx -Times 1 -ParameterFilter {
                $Object -eq '[dx] alpha=1 bravo=2'
            }
        }

        It 'skips output when console level is quiet' {
            Mock -CommandName Write-Host -ModuleName ConsoleUx {}

            InModuleScope ConsoleUx {
                Write-DxKV -Data @{ key = 'value' } -ConsoleLevel 'quiet'
            }

            Assert-MockCalled Write-Host -ModuleName ConsoleUx -Times 0
        }
    }
}
