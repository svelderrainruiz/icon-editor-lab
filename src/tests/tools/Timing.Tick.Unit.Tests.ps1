[CmdletBinding()]
param()
#Requires -Version 7.0

Describe 'Timing tick helpers' -Tag 'Unit','Tools','Timing' {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
        $script:modulePath = (Resolve-Path (Join-Path $script:RepoRoot 'src\tools\Timing\Tick.psm1')).Path
        if (Get-Module -Name Tick -ErrorAction SilentlyContinue) {
            Remove-Module Tick -Force -ErrorAction SilentlyContinue
        }
        $module = New-Module -Name Tick -ScriptBlock {
            param($path)
            . $path
        } -ArgumentList $script:modulePath
        Import-Module $module -Force
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
