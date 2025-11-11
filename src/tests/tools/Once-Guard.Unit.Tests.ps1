[CmdletBinding()]
param()
#Requires -Version 7.0

Describe 'Invoke-Once guard' -Tag 'Unit','Tools','OnceGuard' {
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
        $script:modulePath = (Resolve-Path (Join-Path $script:RepoRoot 'src/tools/Once-Guard.psm1')).Path
        if (Get-Module -Name 'Once-Guard' -ErrorAction SilentlyContinue) {
            Remove-Module 'Once-Guard' -Force -ErrorAction SilentlyContinue
        }
        Import-Module -Name $script:modulePath -Force -ErrorAction Stop
    }

    AfterAll {
        if (Get-Module -Name 'Once-Guard' -ErrorAction SilentlyContinue) {
            Remove-Module 'Once-Guard' -Force -ErrorAction SilentlyContinue
        }
    }

    It 'executes the action once and records a marker' {
        $scope = Join-Path $TestDrive 'once'
        $counter = [ref]0
        Invoke-Once -Key 'alpha' -ScopeDirectory $scope -Action {
            $counter.Value++
        } | Should -BeTrue

        Invoke-Once -Key 'alpha' -ScopeDirectory $scope -Action {
            $counter.Value++
        } | Should -BeFalse

        $counter.Value | Should -Be 1
        $marker = Join-Path $scope 'once-alpha.marker'
        Test-Path $marker | Should -BeTrue
        (Get-Content $marker | ConvertFrom-Json).key | Should -Be 'alpha'
    }

    It 'creates scope directory when missing' {
        $scope = Join-Path $TestDrive 'missing' 'nested'
        Test-Path $scope | Should -BeFalse

        Invoke-Once -Key 'make-scope' -ScopeDirectory $scope -Action { } | Should -BeTrue

        Test-Path $scope | Should -BeTrue
    }

    It 'respects WhatIf flag and still records completion metadata' {
        $scope = Join-Path $TestDrive 'whatif'
        $ran = [ref]$false

        Invoke-Once -Key 'noop' -ScopeDirectory $scope -Action {
            $ran.Value = $true
        } -WhatIf | Should -BeTrue

        $ran.Value | Should -BeFalse
        Test-Path $scope | Should -BeTrue
        (Get-ChildItem -Path $scope | Measure-Object).Count | Should -Be 1
    }
}
