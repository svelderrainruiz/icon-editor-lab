[CmdletBinding()]
param()
#Requires -Version 7.0

Describe 'Invoke-Once guard' -Tag 'Unit','Tools','OnceGuard' {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
        $script:modulePath = (Resolve-Path (Join-Path $script:RepoRoot 'src\tools\Once-Guard.psm1')).Path
        if (Get-Module -Name 'Once-Guard' -ErrorAction SilentlyContinue) {
            Remove-Module 'Once-Guard' -Force -ErrorAction SilentlyContinue
        }
        $module = New-Module -Name 'Once-Guard' -ScriptBlock {
            param($path)
            . $path
        } -ArgumentList $script:modulePath
        Import-Module $module -Force
    }

    AfterAll {
        if (Get-Module -Name 'Once-Guard' -ErrorAction SilentlyContinue) {
            Remove-Module 'Once-Guard' -Force -ErrorAction SilentlyContinue
        }
    }

    It 'executes the action once and records a marker' {
        $scope = Join-Path $TestDrive 'once'
        $counter = [ref]0
        InModuleScope 'Once-Guard' {
            Invoke-Once -Key 'alpha' -ScopeDirectory $scope -Action {
                $counter.Value++
            } | Should -BeTrue

            Invoke-Once -Key 'alpha' -ScopeDirectory $scope -Action {
                $counter.Value++
            } | Should -BeFalse
        }

        $counter.Value | Should -Be 1
        $marker = Join-Path $scope 'once-alpha.marker'
        Test-Path $marker | Should -BeTrue
        (Get-Content $marker | ConvertFrom-Json).key | Should -Be 'alpha'
    }

    It 'creates scope directory when missing' {
        $scope = Join-Path $TestDrive 'missing' 'nested'
        Test-Path $scope | Should -BeFalse

        InModuleScope 'Once-Guard' {
            Invoke-Once -Key 'make-scope' -ScopeDirectory $scope -Action { } | Should -BeTrue
        }

        Test-Path $scope | Should -BeTrue
    }

    It 'respects WhatIf flag and still records completion metadata' {
        $scope = Join-Path $TestDrive 'whatif'
        $ran = [ref]$false

        InModuleScope 'Once-Guard' {
            Invoke-Once -Key 'noop' -ScopeDirectory $scope -Action {
                $ran.Value = $true
            } -WhatIf | Should -BeTrue
        }

        $ran.Value | Should -BeFalse
        Test-Path $scope | Should -BeTrue
        (Get-ChildItem -Path $scope | Measure-Object).Count | Should -Be 1
    }
}
