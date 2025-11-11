[CmdletBinding()]
param()
#Requires -Version 7.0

Describe 'LabVIEW PID tracker helpers' -Tag 'Unit','Tools','LabVIEWPidTracker' {
    BeforeAll {
        $modulePath = & {
            $startingDirs = @()
            if ($PSScriptRoot) { $startingDirs += $PSScriptRoot }
            if ($PSCommandPath) { $startingDirs += (Split-Path -Parent $PSCommandPath) }
            if ($MyInvocation.MyCommand.Path) { $startingDirs += (Split-Path -Parent $MyInvocation.MyCommand.Path) }
            $startingDirs += (Get-Location).ProviderPath

            foreach ($dir in ($startingDirs | Where-Object { $_ -and (Test-Path $_) })) {
                $resolved = Resolve-Path -LiteralPath $dir -ErrorAction SilentlyContinue
                if (-not $resolved) { continue }
                $current = $resolved.ProviderPath
                while ($current) {
                    $candidate = Join-Path $current 'src/tools/LabVIEWPidTracker.psm1'
                    if (Test-Path -LiteralPath $candidate) {
                        return (Resolve-Path -LiteralPath $candidate).ProviderPath
                    }
                    $parent = Split-Path -Parent $current
                    if (-not $parent -or $parent -eq $current) { break }
                    $current = $parent
                }
            }

            throw 'Unable to locate LabVIEWPidTracker module for tests.'
        }
        Import-Module -Name $modulePath -Force
    }

    AfterAll {
        if (Get-Module -Name LabVIEWPidTracker -ErrorAction SilentlyContinue) {
            Remove-Module LabVIEWPidTracker -Force
        }
    }

    Context 'Resolve-LabVIEWPidContext' {
        It 'returns null when context parameter is missing or null' {
            Resolve-LabVIEWPidContext | Should -BeNullOrEmpty
            Resolve-LabVIEWPidContext -Context $null | Should -BeNullOrEmpty
        }

        It 'orders hash tables and nested objects recursively' {
            $input = @{
                bravo = 2
                alpha = @{ delta = 4; charlie = 3 }
            }
            $result = Resolve-LabVIEWPidContext -Context $input -Confirm:$false
            ($result | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name) | Should -Be @('alpha','bravo')
            ($result.alpha | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name) | Should -Be @('charlie','delta')
            $result.alpha.charlie | Should -Be 3
            $result.bravo | Should -Be 2
        }

        It 'normalizes enumerable contexts and preserves order' {
            $input = @(
                @{ zeta = 2; alpha = 1 },
                42,
                @('delta','beta')
            )
            $result = Resolve-LabVIEWPidContext -Context $input -Confirm:$false
            $result.Count | Should -Be 3
            ($result[0] | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name) | Should -Be @('alpha','zeta')
            $result[1] | Should -Be 42
            $result[2][0] | Should -Be 'delta'
            $result[2][1] | Should -Be 'beta'
        }
    }

    Context 'Tracker lifecycle' {
        BeforeEach {
            $script:labProcess = [pscustomobject]@{
                Id = 4242
                ProcessName = 'LabVIEW'
                StartTime = (Get-Date '2025-11-11T00:00:00Z')
            }
            $script:timestamp = Get-Date '2025-11-11T00:00:00Z'
            Mock -ModuleName LabVIEWPidTracker -CommandName Get-Date -MockWith { $script:timestamp }
            Mock -ModuleName LabVIEWPidTracker -CommandName Get-Process -ParameterFilter { $PSBoundParameters['Name'] -eq 'LabVIEW' } -MockWith {
                return ,$script:labProcess
            }
            Mock -ModuleName LabVIEWPidTracker -CommandName Get-Process -ParameterFilter { $PSBoundParameters.ContainsKey('Id') } -MockWith {
                if ($Id -eq $script:labProcess.Id) { return $script:labProcess }
                throw [System.ComponentModel.Win32Exception]::new("Process $Id not found")
            }
        }

        It 'records initialize observation with active LabVIEW process' {
            $tracker = Join-Path $TestDrive 'pid-tracker' 'tracker.json'
            $result = Start-LabVIEWPidTracker -TrackerPath $tracker -Source 'tests'
            $result.Observation.action | Should -Be 'initialize'
            Test-Path $tracker | Should -BeTrue
            $record = Get-Content $tracker -Raw | ConvertFrom-Json -Depth 6
            $record.observations[-1].action | Should -Be 'initialize'
        }

        It 'reuses running pid captured in tracker file' {
            $tracker = Join-Path $TestDrive 'reuse' 'tracker.json'
            $dir = Split-Path -Parent $tracker
            if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
            $state = [ordered]@{
                schema       = 'labview-pid-tracker/v1'
                updatedAt    = $script:timestamp.ToString('o')
                pid          = 5555
                running      = $true
                reused       = $true
                observations = @([ordered]@{ action = 'initialize'; pid = 5555; running = $true; at = $script:timestamp.ToString('o') })
            }
            $state | ConvertTo-Json -Depth 6 | Set-Content -Path $tracker
            $script:labProcess.Id = 5555
            $result = Start-LabVIEWPidTracker -TrackerPath $tracker -Source 'tests'
            $result.Observation.note | Should -BeIn @('reused-existing','selected-from-scan','labview-not-running')
            $updated = Get-Content $tracker -Raw | ConvertFrom-Json -Depth 6
            ($updated.observations | Measure-Object).Count | Should -BeGreaterThan 0
        }

        It 'records reused pid metadata when tracker is still running' {
            $tracker = Join-Path $TestDrive 'reuse-meta' 'tracker.json'
            $dir = Split-Path -Parent $tracker
            if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
            $state = [ordered]@{
                schema       = 'labview-pid-tracker/v1'
                updatedAt    = $script:timestamp.ToString('o')
                pid          = 6006
                running      = $true
                reused       = $true
                observations = @()
            }
            $state | ConvertTo-Json -Depth 6 | Set-Content -Path $tracker
            $script:labProcess.Id = 6006
            $result = Start-LabVIEWPidTracker -TrackerPath $tracker -Source 'tests'
            $result.Reused | Should -BeTrue
            $result.Running | Should -BeTrue
            $result.Observation.note | Should -Be 'reused-existing'
            $record = Get-Content $tracker -Raw | ConvertFrom-Json -Depth 6
            $record.reused | Should -BeTrue
            ($record.observations | Select-Object -Last 1).note | Should -Be 'reused-existing'
        }

        It 'notes when LabVIEW is not running' {
            $tracker = Join-Path $TestDrive 'noproc' 'tracker.json'
            Mock -ModuleName LabVIEWPidTracker -CommandName Get-Process -ParameterFilter { $PSBoundParameters['Name'] -eq 'LabVIEW' } -MockWith { @() }
            Mock -ModuleName LabVIEWPidTracker -CommandName Get-Process -ParameterFilter { $PSBoundParameters.ContainsKey('Id') } -MockWith { throw [System.ComponentModel.Win32Exception]::new('missing') }
            $result = Start-LabVIEWPidTracker -TrackerPath $tracker -Source 'tests'
            $result.Pid | Should -BeNullOrEmpty
            $result.Observation.note | Should -Be 'labview-not-running'
        }

        It 'persists labview-not-running note in tracker file' {
            $tracker = Join-Path $TestDrive 'noproc-file' 'tracker.json'
            Mock -ModuleName LabVIEWPidTracker -CommandName Get-Process -ParameterFilter { $PSBoundParameters['Name'] -eq 'LabVIEW' } -MockWith { @() }
            Mock -ModuleName LabVIEWPidTracker -CommandName Get-Process -ParameterFilter { $PSBoundParameters.ContainsKey('Id') } -MockWith { throw [System.ComponentModel.Win32Exception]::new('missing') }
            $result = Start-LabVIEWPidTracker -TrackerPath $tracker -Source 'tests'
            $result.Observation.note | Should -Be 'labview-not-running'
            $record = Get-Content $tracker -Raw | ConvertFrom-Json -Depth 6
            $record.running | Should -BeFalse
            ($record.observations | Select-Object -Last 1).note | Should -Be 'labview-not-running'
        }

        It 'finalizes tracker when tracked process is gone' {
            $tracker = Join-Path $TestDrive 'pid-finalize' 'tracker.json'
            $null = Start-LabVIEWPidTracker -TrackerPath $tracker -Source 'tests'
            Mock -ModuleName LabVIEWPidTracker -CommandName Get-Process -ParameterFilter { $PSBoundParameters.ContainsKey('Id') } -MockWith {
                throw [System.ComponentModel.Win32Exception]::new("process not running")
            } -Verifiable
            $result = Stop-LabVIEWPidTracker -TrackerPath $tracker -Source 'tests'
            $result.Observation.action | Should -Be 'finalize'
            $result.Observation.running | Should -BeFalse
            $result.Observation.note | Should -Be 'no-tracked-pid'
            $record = Get-Content $tracker -Raw | ConvertFrom-Json -Depth 6
            ($record.observations | Select-Object -Last 1).action | Should -Be 'finalize'
        }

        It 'propagates context data during stop observations' {
            $tracker = Join-Path $TestDrive 'context-stop' 'tracker.json'
            $dir = Split-Path -Parent $tracker
            if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
            $state = [ordered]@{
                schema       = 'labview-pid-tracker/v1'
                updatedAt    = $script:timestamp.ToString('o')
                pid          = 7777
                running      = $false
                reused       = $true
                observations = @()
            }
            $state | ConvertTo-Json -Depth 6 | Set-Content -Path $tracker
            Mock -ModuleName LabVIEWPidTracker -CommandName Get-Process -ParameterFilter { $PSBoundParameters.ContainsKey('Id') } -MockWith {
                throw [System.ComponentModel.Win32Exception]::new("gone")
            }
            $context = @{
                env = @('dev','qa')
                meta = @{ branch = 'feature'; build = 42 }
            }
            $result = Stop-LabVIEWPidTracker -TrackerPath $tracker -Source 'tests' -Context $context
            $result.Pid | Should -BeNullOrEmpty
            $result.Observation.note | Should -Be 'no-tracked-pid'
            $result.Context.env[0] | Should -Be 'dev'
            $result.ContextSource | Should -Be 'tests'
        }

        It 'records still-running note when tracked pid remains active' {
            $tracker = Join-Path $TestDrive 'still-running' 'tracker.json'
            $dir = Split-Path -Parent $tracker
            if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
            $state = [ordered]@{
                schema       = 'labview-pid-tracker/v1'
                updatedAt    = $script:timestamp.ToString('o')
                pid          = 8888
                running      = $true
                reused       = $false
                observations = @()
            }
            $state | ConvertTo-Json -Depth 6 | Set-Content -Path $tracker
            Mock -ModuleName LabVIEWPidTracker -CommandName Get-Process -ParameterFilter { $PSBoundParameters.ContainsKey('Id') } -MockWith {
                if ($Id -eq 8888) {
                    return [pscustomobject]@{ Id = 8888; ProcessName = 'LabVIEW' }
                }
                throw [System.ComponentModel.Win32Exception]::new("Process $Id not found")
            }
            $result = Stop-LabVIEWPidTracker -TrackerPath $tracker -Source 'tests'
            $result.Observation.note | Should -Be 'still-running'
            $result.Running | Should -BeTrue
            $record = Get-Content $tracker -Raw | ConvertFrom-Json -Depth 6
            ($record.observations | Select-Object -Last 1).note | Should -Be 'still-running'
            $record.running | Should -BeTrue
        }
    }
}
