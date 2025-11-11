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

    It 'rounds elapsed milliseconds when reading counters' {
        InModuleScope Tick {
            $counter = Start-TickCounter -TickMilliseconds 10
            Wait-Tick -Counter $counter -Milliseconds 1 | Out-Null
            $snapshot = Read-TickCounter -Counter $counter
            $snapshot.elapsedMs | Should -BeGreaterThan 0
            $snapshot.intervalMs | Should -Be 10
            Stop-TickCounter -Counter $counter
        }
    }

    It 'stops the stopwatch when Stop-TickCounter is invoked' {
        InModuleScope Tick {
            $counter = Start-TickCounter -TickMilliseconds 2
            Stop-TickCounter -Counter $counter
            $counter.stopwatch.IsRunning | Should -BeFalse
        }
    }

    It 'clamps wait intervals and respects instrumentation toggle' {
        InModuleScope Tick {
            $counter = Start-TickCounter -TickMilliseconds 4
            Mock -ModuleName Tick -CommandName Invoke-TickDelay
            Wait-Tick -Counter $counter -Milliseconds 0 | Out-Null
            Assert-MockCalled -CommandName Invoke-TickDelay -ModuleName Tick -Times 1 -ParameterFilter { $Milliseconds -eq 1 }
            $script:TickInstrumentationEnabled = $false
            Wait-Tick -Counter $counter -Milliseconds 50 | Out-Null
            Assert-MockCalled -CommandName Invoke-TickDelay -ModuleName Tick -Times 1
            $script:TickInstrumentationEnabled = $true
            Stop-TickCounter -Counter $counter
        }
    }

    It 'handles null counter and missing stopwatch gracefully' {
        InModuleScope Tick {
            Wait-Tick -Counter $null -Milliseconds 0 | Should -BeNullOrEmpty
            { Stop-TickCounter -Counter ([pscustomobject]@{ ticks = 0; stopwatch = $null }) } | Should -Not -Throw
        }
    }

    Context 'Support utilities' {
        It 'validates labels using Test-ValidLabel' {
            InModuleScope Tick {
                { Test-ValidLabel -Label 'alpha-123_Release.1' } | Should -Not -Throw
                { Test-ValidLabel -Label 'bad label!' } | Should -Throw '*Invalid label*'
            }
        }

        It 'runs Invoke-WithTimeout successfully and handles timeouts' {
            InModuleScope Tick {
                $jobId = 99
                Mock -CommandName Start-Job -MockWith {
                    param([scriptblock]$ScriptBlock)
                    & $ScriptBlock | Out-Null
                    return $jobId
                }
                Mock -CommandName Wait-Job -MockWith {
                    param([int[]]$Id,[Parameter(ValueFromRemainingArguments=$true)][object[]]$Ignore)
                    $true
                }
                Mock -CommandName Receive-Job -MockWith {
                    param([int[]]$Id,[Parameter(ValueFromRemainingArguments=$true)][object[]]$Ignore)
                    'done'
                }
                Invoke-WithTimeout -ScriptBlock { 'work' } -TimeoutSec 5 | Should -Be 'done'

                Mock -CommandName Wait-Job -MockWith {
                    param([int[]]$Id,[Parameter(ValueFromRemainingArguments=$true)][object[]]$Ignore)
                    $false
                }
                Mock -CommandName Stop-Job -MockWith {
                    param([int[]]$Id,[Parameter(ValueFromRemainingArguments=$true)][object[]]$Ignore)
                }
                { Invoke-WithTimeout -ScriptBlock { Start-Sleep -Milliseconds 10 } -TimeoutSec 0 } | Should -Throw '*timed out*'
            }
        }
    }
}

