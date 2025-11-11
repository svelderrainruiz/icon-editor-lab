[CmdletBinding()]
param()
#Requires -Version 7.0

Describe 'LabVIEW PID tracker helpers' -Tag 'Unit','Tools','LabVIEWPidTracker' {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
        $script:modulePath = (Resolve-Path (Join-Path $script:RepoRoot 'src/tools/LabVIEWPidTracker.psm1')).Path
        if (Get-Module -Name LabVIEWPidTracker -ErrorAction SilentlyContinue) {
            Remove-Module LabVIEWPidTracker -Force -ErrorAction SilentlyContinue
        }
        Import-Module -Name $script:modulePath -Force -ErrorAction Stop
    }

    AfterAll {
        if (Get-Module -Name LabVIEWPidTracker -ErrorAction SilentlyContinue) {
            Remove-Module LabVIEWPidTracker -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Resolve-LabVIEWPidContext' {
        It 'returns null when context parameter is missing or null' {
            InModuleScope LabVIEWPidTracker {
                Resolve-LabVIEWPidContext | Should -BeNullOrEmpty
                Resolve-LabVIEWPidContext -Context $null | Should -BeNullOrEmpty
            }
        }

        It 'orders hash tables and nested objects recursively' {
            $nested = @{ delta = 4; charlie = 3 }
            $input = @{
                bravo = 2
                alpha = $nested
            }
            InModuleScope LabVIEWPidTracker {
                $result = Resolve-LabVIEWPidContext -Context $input
                $result.psobject.Properties.Name | Should -Be @('alpha','bravo')
                $result.alpha.psobject.Properties.Name | Should -Be @('charlie','delta')
                $result.alpha.charlie | Should -Be 3
                $result.bravo | Should -Be 2
            }
        }
    }

    Context 'Tracker lifecycle' {
        BeforeEach {
            $script:labProcess = [pscustomobject]@{
                Id = 4242
                ProcessName = 'LabVIEW'
            }
            $script:now = Get-Date '2025-11-11T00:00:00Z'
            Mock -ModuleName LabVIEWPidTracker -CommandName Get-Date -MockWith { return $script:now }
            Mock -ModuleName LabVIEWPidTracker -CommandName Get-Process -ParameterFilter { $PSBoundParameters.ContainsKey('Name') -and $Name -eq 'LabVIEW' } -MockWith {
                return ,$script:labProcess
            }
            Mock -ModuleName LabVIEWPidTracker -CommandName Get-Process -ParameterFilter { $PSBoundParameters.ContainsKey('Id') } -MockWith {
                if ($Id -eq $script:labProcess.Id) { return $script:labProcess }
                throw [System.ComponentModel.Win32Exception]::new("Process $Id not found")
            }
        }

        It 'records initialize observation with active LabVIEW process' {
            $tracker = Join-Path $TestDrive 'pid-tracker' 'tracker.json'
            InModuleScope LabVIEWPidTracker {
                $result = Start-LabVIEWPidTracker -TrackerPath $tracker -Source 'tests'
                $result.Pid | Should -Be $script:labProcess.Id
                $result.Observation.action | Should -Be 'initialize'
                $result.Observation.running | Should -BeTrue
            }
            Test-Path $tracker | Should -BeTrue
            $record = Get-Content $tracker -Raw | ConvertFrom-Json -Depth 6
            $record.pid | Should -Be $script:labProcess.Id
            $record.observations[-1].action | Should -Be 'initialize'
        }

        It 'finalizes tracker when tracked process is gone' {
            $tracker = Join-Path $TestDrive 'pid-finalize' 'tracker.json'
            InModuleScope LabVIEWPidTracker {
                $null = Start-LabVIEWPidTracker -TrackerPath $tracker -Source 'tests'
                # override Id lookup to simulate process missing
                Mock -ModuleName LabVIEWPidTracker -CommandName Get-Process -ParameterFilter { $PSBoundParameters.ContainsKey('Id') } -MockWith {
                    throw [System.ComponentModel.Win32Exception]::new("process not running")
                } -Verifiable
                $result = Stop-LabVIEWPidTracker -TrackerPath $tracker -Source 'tests'
                $result.Observation.action | Should -Be 'finalize'
                $result.Observation.running | Should -BeFalse
                $result.Observation.note | Should -Be 'no-tracked-pid'
            }
            $record = Get-Content $tracker -Raw | ConvertFrom-Json -Depth 6
            ($record.observations | Select-Object -Last 1).action | Should -Be 'finalize'
        }
    }
}
