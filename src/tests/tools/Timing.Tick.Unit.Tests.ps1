[CmdletBinding()]
param()
#Requires -Version 7.0

Describe 'Timing tick helpers' -Tag 'Unit','Tools','Timing' {
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
        $script:modulePath = (Resolve-Path (Join-Path $script:RepoRoot 'src/tools/Timing/Tick.psm1')).Path
        if (Get-Module -Name Tick -ErrorAction SilentlyContinue) {
            Remove-Module Tick -Force -ErrorAction SilentlyContinue
        }
        Import-Module -Name $script:modulePath -Force -ErrorAction Stop
    }

    AfterAll {
        if (Get-Module -Name Tick -ErrorAction SilentlyContinue) {
            Remove-Module Tick -Force -ErrorAction SilentlyContinue
        }
    }

    It 'enforces minimum tick interval when starting counters' {
        InModuleScope Tick {
            $counter = Start-TickCounter -TickMilliseconds 0
            $counter.tickMilliseconds | Should -Be 1
            $counter.stopwatch.IsRunning | Should -BeTrue
            Stop-TickCounter -Counter $counter
        }
    }

    It 'increments tick counts when waiting' {
        InModuleScope Tick {
            $counter = Start-TickCounter -TickMilliseconds 5
            Wait-Tick -Counter $counter -Milliseconds 1 | Out-Null
            Wait-Tick -Counter $counter -Milliseconds 1 | Out-Null
            $snapshot = Read-TickCounter -Counter $counter
            $snapshot.ticks | Should -Be 2
            $snapshot.intervalMs | Should -Be 5
            Stop-TickCounter -Counter $counter
        }
    }

    It 'returns null when reading an uninitialized counter' {
        InModuleScope Tick {
            Read-TickCounter -Counter $null | Should -BeNullOrEmpty
        }
    }
}
