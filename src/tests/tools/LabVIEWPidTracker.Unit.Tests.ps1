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

        It 'orders PSCustomObject properties case-sensitively' {
            $input = [pscustomobject]@{}
            $input | Add-Member -NotePropertyName 'bravo' -NotePropertyValue 2
            $input | Add-Member -NotePropertyName 'Alpha' -NotePropertyValue 1
            $input | Add-Member -NotePropertyName 'delta' -NotePropertyValue 3
            $result = Resolve-LabVIEWPidContext -Context $input -Confirm:$false
            ($result | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name) | Should -Be @('Alpha','bravo','delta')
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
            Mock -ModuleName LabVIEWPidTracker -CommandName Get-Process -ParameterFilter {
                $null -ne $Name -and ($Name -contains 'LabVIEW')
            } -MockWith {
                return ,$script:labProcess
            }
            Mock -ModuleName LabVIEWPidTracker -CommandName Get-Process -ParameterFilter { $null -ne $Id } -MockWith {
                if ($Id -contains $script:labProcess.Id) { return $script:labProcess }
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
            Mock -ModuleName LabVIEWPidTracker -CommandName Get-Process -ParameterFilter { $null -ne $Name -and ($Name -contains 'LabVIEW') } -MockWith { @() }
            Mock -ModuleName LabVIEWPidTracker -CommandName Get-Process -ParameterFilter { $null -ne $Id } -MockWith { throw [System.ComponentModel.Win32Exception]::new('missing') }
            $result = Start-LabVIEWPidTracker -TrackerPath $tracker -Source 'tests'
            $result.Pid | Should -BeNullOrEmpty
            $result.Observation.note | Should -Be 'labview-not-running'
        }

        It 'persists labview-not-running note in tracker file' {
            $tracker = Join-Path $TestDrive 'noproc-file' 'tracker.json'
            Mock -ModuleName LabVIEWPidTracker -CommandName Get-Process -ParameterFilter { $null -ne $Name -and ($Name -contains 'LabVIEW') } -MockWith { @() }
            Mock -ModuleName LabVIEWPidTracker -CommandName Get-Process -ParameterFilter { $null -ne $Id } -MockWith { throw [System.ComponentModel.Win32Exception]::new('missing') }
            $result = Start-LabVIEWPidTracker -TrackerPath $tracker -Source 'tests'
            $result.Observation.note | Should -Be 'labview-not-running'
            $record = Get-Content $tracker -Raw | ConvertFrom-Json -Depth 6
            $record.running | Should -BeFalse
            ($record.observations | Select-Object -Last 1).note | Should -Be 'labview-not-running'
        }

        It 'finalizes tracker when tracked process is gone' {
            $tracker = Join-Path $TestDrive 'pid-finalize' 'tracker.json'
            $null = Start-LabVIEWPidTracker -TrackerPath $tracker -Source 'tests'
            Mock -ModuleName LabVIEWPidTracker -CommandName Get-Process -ParameterFilter { $null -ne $Id } -MockWith {
                throw [System.ComponentModel.Win32Exception]::new("process not running")
            } -Verifiable
            $result = Stop-LabVIEWPidTracker -TrackerPath $tracker -Source 'tests'
            $result.Observation.action | Should -Be 'finalize'
            $result.Observation.running | Should -BeFalse
            $result.Observation.note | Should -Be 'not-running'
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
            Mock -ModuleName LabVIEWPidTracker -CommandName Get-Process -ParameterFilter { $null -ne $Id } -MockWith {
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
            $script:labProcess.Id = 8888
            $result = Stop-LabVIEWPidTracker -TrackerPath $tracker -Source 'tests'
            $result.Observation.note | Should -Be 'still-running'
            $result.Running | Should -BeTrue
            $record = Get-Content $tracker -Raw | ConvertFrom-Json -Depth 6
            ($record.observations | Select-Object -Last 1).note | Should -Be 'still-running'
            $record.running | Should -BeTrue
        }
    }

    Context 'Start-LabVIEWPidTracker edge cases' {
        It 'recovers from invalid tracker JSON state' {
            $tracker = Join-Path $TestDrive 'invalid-json' 'tracker.json'
            New-Item -ItemType Directory -Path (Split-Path -Parent $tracker) -Force | Out-Null
            Set-Content -Path $tracker -Value '{ invalid json'
            Mock -ModuleName LabVIEWPidTracker -CommandName Get-Date -MockWith { Get-Date '2025-05-01T00:00:00Z' }
            Mock -ModuleName LabVIEWPidTracker -CommandName Get-Process -ParameterFilter { $null -ne $Name -and ($Name -contains 'LabVIEW') } -MockWith { @() }
            Mock -ModuleName LabVIEWPidTracker -CommandName Get-Process -ParameterFilter { $null -ne $Id } -MockWith { throw 'no pid' }
            $result = Start-LabVIEWPidTracker -TrackerPath $tracker -Source 'tests'
            $result.Observation.note | Should -Be 'labview-not-running'
        }

        It 'sorts fresh LabVIEW processes by StartTime' {
            $older = [pscustomobject]@{ Id = 111; ProcessName = 'LabVIEW'; StartTime = Get-Date '2025-02-01T00:00:05Z' }
            $newer = [pscustomobject]@{ Id = 222; ProcessName = 'LabVIEW'; StartTime = Get-Date '2025-02-01T00:10:05Z' }
            Mock -ModuleName LabVIEWPidTracker -CommandName Get-Date -MockWith { Get-Date '2025-02-01T00:15:00Z' }
            Mock -ModuleName LabVIEWPidTracker -CommandName Get-Process -ParameterFilter { $null -ne $Name -and ($Name -contains 'LabVIEW') } -MockWith {
                @($newer,$older)
            }
            Mock -ModuleName LabVIEWPidTracker -CommandName Get-Process -ParameterFilter { $null -ne $Id } -MockWith {
                param($Id)
                if ($Id -eq 111) { return $older }
                if ($Id -eq 222) { return $newer }
                throw 'missing'
            }
            $tracker = Join-Path $TestDrive 'sorted' 'tracker.json'
            $result = Start-LabVIEWPidTracker -TrackerPath $tracker -Source 'tests'
            $result.Pid | Should -Be 111
            $result.Observation.note | Should -Be 'selected-from-scan'
        }

        It 'continues when candidate sorting throws' {
            $candidate = [pscustomobject]@{ Id = 303; ProcessName = 'LabVIEW'; StartTime = Get-Date '2025-03-01T00:00:00Z' }
            Mock -ModuleName LabVIEWPidTracker -CommandName Get-Date -MockWith { Get-Date '2025-03-01T00:01:00Z' }
            Mock -ModuleName LabVIEWPidTracker -CommandName Get-Process -ParameterFilter { $null -ne $Name -and ($Name -contains 'LabVIEW') } -MockWith {
                @($candidate,$candidate)
            }
            Mock -ModuleName LabVIEWPidTracker -CommandName Get-Process -ParameterFilter { $null -ne $Id } -MockWith { $candidate }
            Mock -ModuleName LabVIEWPidTracker -CommandName Sort-Object -MockWith { throw 'sort fail' }
            $tracker = Join-Path $TestDrive 'sort-fail' 'tracker.json'
            { Start-LabVIEWPidTracker -TrackerPath $tracker -Source 'tests' } | Should -Not -Throw
        }

        It 'records candidates-present when no PID is selected' {
            $proc = [pscustomobject]@{ Id = 404; ProcessName = 'LabVIEW'; StartTime = Get-Date '2025-04-01T00:00:00Z' }
            Mock -ModuleName LabVIEWPidTracker -CommandName Get-Date -MockWith { Get-Date '2025-04-01T00:01:00Z' }
            Mock -ModuleName LabVIEWPidTracker -CommandName Get-Process -ParameterFilter { $null -ne $Name -and ($Name -contains 'LabVIEW') } -MockWith { @($proc) }
            Mock -ModuleName LabVIEWPidTracker -CommandName Get-Process -ParameterFilter { $null -ne $Id } -MockWith { throw 'denied' }
            $tracker = Join-Path $TestDrive 'candidates-present' 'tracker.json'
            $result = Start-LabVIEWPidTracker -TrackerPath $tracker -Source 'tests'
            $result.Observation.note | Should -Be 'candidates-present'
        }

        It 'handles LabVIEW process discovery failures' {
            Mock -ModuleName LabVIEWPidTracker -CommandName Get-Date -MockWith { Get-Date '2025-06-01T00:00:00Z' }
            Mock -ModuleName LabVIEWPidTracker -CommandName Get-Process -ParameterFilter { $null -ne $Name -and ($Name -contains 'LabVIEW') } -MockWith { throw 'down' }
            $tracker = Join-Path $TestDrive 'labview-down' 'tracker.json'
            $result = Start-LabVIEWPidTracker -TrackerPath $tracker -Source 'tests'
            $result.Observation.note | Should -Be 'labview-not-running'
        }
    }

    Context 'Stop-LabVIEWPidTracker edge cases' {
        It 'ignores invalid tracker JSON content' {
            $tracker = Join-Path $TestDrive 'stop-invalid' 'tracker.json'
            New-Item -ItemType Directory -Path (Split-Path -Parent $tracker) -Force | Out-Null
            Set-Content -Path $tracker -Value '{ broken'
            { Stop-LabVIEWPidTracker -TrackerPath $tracker -Source 'tests' } | Should -Not -Throw
        }

        It 'handles non-integer pid stored in tracker state' {
            $tracker = Join-Path $TestDrive 'stop-pid' 'tracker.json'
            New-Item -ItemType Directory -Path (Split-Path -Parent $tracker) -Force | Out-Null
            @"
{ "pid": "not-int", "running": true, "observations": [] }
"@ | Set-Content -Path $tracker
            Stop-LabVIEWPidTracker -TrackerPath $tracker -Source 'tests' | Out-Null
            Test-Path $tracker | Should -BeTrue
        }

        It 'creates parent directories when writing tracker records' {
            $tracker = Join-Path $TestDrive 'deep\sub\tracker.json'
            Stop-LabVIEWPidTracker -TrackerPath $tracker -Source 'tests' | Out-Null
            Test-Path (Split-Path -Parent $tracker) | Should -BeTrue
        }
    }

    Context 'Module helper functions' {
        It 'Test-ValidLabel accepts good labels' {
            InModuleScope LabVIEWPidTracker {
                Test-ValidLabel -Label 'Tracker_1-2.3'
            }
        }

        It 'Test-ValidLabel rejects bad labels' {
            InModuleScope LabVIEWPidTracker {
                { Test-ValidLabel -Label 'bad label!' } | Should -Throw '*Invalid label*'
            }
        }

        It 'Invoke-WithTimeout returns scriptblock result' {
            InModuleScope LabVIEWPidTracker {
                Invoke-WithTimeout -ScriptBlock { 5 } -TimeoutSec 5 | Should -Be 5
            }
        }

        It 'Invoke-WithTimeout throws when timeout exceeded' {
            InModuleScope LabVIEWPidTracker {
                { Invoke-WithTimeout -ScriptBlock { Start-Sleep -Milliseconds 500 } -TimeoutSec 0 } | Should -Throw '*timed out*'
            }
        }
    }
}
