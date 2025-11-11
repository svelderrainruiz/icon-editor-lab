[CmdletBinding()]
param()
#Requires -Version 7.0

Describe 'ConsoleWatch helpers' -Tag 'Unit','Tools','ConsoleWatch' {
    BeforeAll {
        $here = $PSScriptRoot
        if (-not $here -and $PSCommandPath) { $here = Split-Path -Parent $PSCommandPath }
        if (-not $here -and $MyInvocation.MyCommand.Path) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
        if (-not $here) { throw 'Unable to determine test root for ConsoleWatch specs.' }
        $script:RepoRoot = (Resolve-Path (Join-Path $here '..\..\..')).Path
        $script:ModulePath = (Resolve-Path (Join-Path $script:RepoRoot 'src/tools/ConsoleWatch.psm1')).Path
        Import-Module -Name $script:ModulePath -Force
    }

    AfterAll {
        if (Get-Module -Name ConsoleWatch -ErrorAction SilentlyContinue) {
            Remove-Module ConsoleWatch -Force -ErrorAction SilentlyContinue
        }
    }

    AfterEach {
        InModuleScope ConsoleWatch {
            if ($script:ConsoleWatchState) {
                foreach ($key in @($script:ConsoleWatchState.Keys)) {
                    $script:ConsoleWatchState.Remove($key) | Out-Null
                }
            }
        }
    }

    Context 'Write-ConsoleWatchRecord helper' {
        It 'captures metadata and writes to ndjson when target matches' {
            $global:ConsoleWatchTestPath = Join-Path $TestDrive 'events.ndjson'
            InModuleScope ConsoleWatch {
                Mock -CommandName Get-CimInstance -ModuleName ConsoleWatch -MockWith {
                    param([string]$ClassName,[string]$Filter)
                    if ($Filter -like '*ProcessId=42*') { return [pscustomobject]@{ CommandLine = 'pwsh -File build.ps1' } }
                    if ($Filter -like '*ProcessId=1*') { return [pscustomobject]@{ Name = 'cmd.exe' } }
                }
                Mock -CommandName Get-Process -ModuleName ConsoleWatch -MockWith { [pscustomobject]@{ MainWindowHandle = 100 } }
                $script:capturedRecord = Write-ConsoleWatchRecord -Path $global:ConsoleWatchTestPath -TargetsLower @('pwsh') -ProcessId 42 -ProcessName 'PwSh' -ParentProcessId 1
            }
            Remove-Variable -Name ConsoleWatchTestPath -Scope Global -ErrorAction SilentlyContinue
            $record = InModuleScope ConsoleWatch { $script:capturedRecord }
            $record.pid | Should -Be 42
            $record.parentName | Should -Be 'cmd.exe'
            (Get-Content (Join-Path $TestDrive 'events.ndjson') | Measure-Object).Count | Should -BeGreaterThan 0
        }

        It 'returns null and skips writing when process name not tracked' {
            $global:ConsoleWatchSkipPath = Join-Path $TestDrive 'skip.ndjson'
            InModuleScope ConsoleWatch {
                Mock -CommandName Add-Content -ModuleName ConsoleWatch -MockWith { }
                $result = Write-ConsoleWatchRecord -Path $global:ConsoleWatchSkipPath -TargetsLower @('pwsh') -ProcessId 7 -ProcessName 'cmd' -ParentProcessId 0
                $result | Should -BeNullOrEmpty
                Assert-MockCalled -ModuleName ConsoleWatch -CommandName Add-Content -Times 0
            }
            Remove-Variable -Name ConsoleWatchSkipPath -Scope Global -ErrorAction SilentlyContinue
        }

        It 'marks hasWindow false when Get-Process fails' {
            $global:ConsoleWatchWindowPath = Join-Path $TestDrive 'window.ndjson'
            InModuleScope ConsoleWatch {
                Mock -CommandName Get-CimInstance -ModuleName ConsoleWatch -MockWith { $null }
                Mock -CommandName Get-Process -ModuleName ConsoleWatch -MockWith { throw 'boom' }
                $record = Write-ConsoleWatchRecord -Path $global:ConsoleWatchWindowPath -TargetsLower @('pwsh') -ProcessId 9 -ProcessName 'pwsh' -ParentProcessId 0
                $record.hasWindow | Should -BeFalse
            }
            Remove-Variable -Name ConsoleWatchWindowPath -Scope Global -ErrorAction SilentlyContinue
        }

        It 'skips parent resolution when parent process id is zero' {
            InModuleScope ConsoleWatch {
                $script:ParentFilters = New-Object System.Collections.Generic.List[string]
                Mock -CommandName Get-CimInstance -ModuleName ConsoleWatch -MockWith {
                    param([string]$ClassName,[string]$Filter)
                    $script:ParentFilters.Add($Filter) | Out-Null
                    $null
                }
                Write-ConsoleWatchRecord -Path (Join-Path $TestDrive 'parent.ndjson') -TargetsLower @('pwsh') -ProcessId 15 -ProcessName 'pwsh' -ParentProcessId 0 | Out-Null
                $script:ParentFilters | Should -Contain 'ProcessId=15'
                $script:ParentFilters | Should -HaveCount 1
                Remove-Variable -Name ParentFilters -Scope Script -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'Start-ConsoleWatch' {
        It 'registers CIM events and seeds ndjson when watcher succeeds' {
            $outDir = Join-Path $TestDrive 'event-mode'
            Mock -CommandName Register-CimIndicationEvent -ModuleName ConsoleWatch -MockWith {
                param(
                    [string]$ClassName,
                    [string]$SourceIdentifier,
                    [scriptblock]$Action,
                    [Parameter(ValueFromRemainingArguments=$true)][object[]]$Remaining
                )
                [pscustomobject]@{ SourceIdentifier = $SourceIdentifier }
            }
            $id = Start-ConsoleWatch -OutDir $outDir -Targets @('PwSh',' CMD ')
            Test-Path (Join-Path $outDir 'console-spawns.ndjson') | Should -BeTrue
            $state = InModuleScope ConsoleWatch { param($key) $script:ConsoleWatchState[$key] } -ArgumentList $id
            $state.Mode | Should -Be 'event'
            $state.Targets | Should -Be @('pwsh','cmd')
            Assert-MockCalled -ModuleName ConsoleWatch -CommandName Register-CimIndicationEvent -Times 1
        }

        It 'ensures snapshot summaries preserve pre-existing captures when no new events' {
            $id = Start-ConsoleWatch -OutDir (Join-Path $TestDrive 'watch-snapshot') -Targets @('pwsh')
            $state = InModuleScope ConsoleWatch { param($key) $script:ConsoleWatchState[$key] } -ArgumentList $id
            $state.Mode | Should -Not -BeNullOrEmpty
            $state.Targets | Should -Contain 'pwsh'
        }

        It 'falls back to snapshot mode when event registration fails' {
            $outDir = Join-Path $TestDrive 'snapshot-fallback'
            Mock -CommandName Register-CimIndicationEvent -ModuleName ConsoleWatch -MockWith { throw 'nope' }
            Mock -CommandName Get-Process -ModuleName ConsoleWatch -MockWith {
                [pscustomobject]@{ ProcessName='pwsh'; Id=123; StartTime=(Get-Date) }
            }
            $id = Start-ConsoleWatch -OutDir $outDir -Targets @('pwsh')
            $state = InModuleScope ConsoleWatch { param($key) $script:ConsoleWatchState[$key] } -ArgumentList $id
            $state.Mode | Should -Be 'snapshot'
            $state.Pre | Should -HaveCount 1
            $state.Targets | Should -Contain 'pwsh'
        }
    }

    Context 'Stop-ConsoleWatch' {
        It 'aggregates event-mode records into a summary' {
            $outDir = Join-Path $TestDrive 'event-summary'
            New-Item -ItemType Directory -Force -Path $outDir | Out-Null
            $global:ConsoleWatchEventDir = $outDir
            $records = @(
                @{ ts = '2025-11-11T00:00:00Z'; pid = 11; name = 'pwsh'; ppid = 1; parentName = 'cmd'; cmd = 'pwsh -NoLogo'; hasWindow = $true },
                @{ ts = '2025-11-11T00:00:01Z'; pid = 12; name = 'pwsh'; ppid = 1; parentName = 'cmd'; cmd = 'pwsh -File build.ps1'; hasWindow = $false },
                @{ ts = '2025-11-11T00:00:02Z'; pid = 21; name = 'cmd';  ppid = 0; parentName = $null; cmd = 'cmd.exe /c'; hasWindow = $true }
            )
            $recPath = Join-Path $outDir 'console-spawns.ndjson'
            $global:ConsoleWatchEventRecordsPath = $recPath
            $records | ForEach-Object { $_ | ConvertTo-Json -Compress } | Set-Content -LiteralPath $recPath -Encoding utf8
            $id = 'ConsoleWatch_test'
            $global:ConsoleWatchEventId = $id
            InModuleScope ConsoleWatch {
                $script:ConsoleWatchState[$global:ConsoleWatchEventId] = @{ Mode='event'; OutDir=$global:ConsoleWatchEventDir; Targets=@('pwsh','cmd'); Path=$global:ConsoleWatchEventRecordsPath }
            }
            Mock -CommandName Unregister-Event -ModuleName ConsoleWatch -MockWith {
                param([Parameter(ValueFromRemainingArguments=$true)][object[]]$Ignore)
            }
            Mock -CommandName Remove-Event -ModuleName ConsoleWatch -MockWith {
                param([Parameter(ValueFromRemainingArguments=$true)][object[]]$Ignore)
            }
            $summary = Stop-ConsoleWatch -Id $global:ConsoleWatchEventId -OutDir $global:ConsoleWatchEventDir -Phase 'post'
            $summary.counts.pwsh | Should -Be 2
            $summary.counts.cmd | Should -Be 1
            ($summary.last | Measure-Object).Count | Should -Be 3
            Test-Path (Join-Path $outDir 'console-watch-summary.json') | Should -BeTrue
            Remove-Variable -Name ConsoleWatchEventDir,ConsoleWatchEventRecordsPath,ConsoleWatchEventId -Scope Global -ErrorAction SilentlyContinue
        }

        It 'detects new processes in snapshot mode' {
            $outDir = Join-Path $TestDrive 'snapshot-summary'
            New-Item -ItemType Directory -Force -Path $outDir | Out-Null
            $global:ConsoleWatchSnapshotDir = $outDir
            $id = 'ConsoleWatch_snapshot'
            $global:ConsoleWatchSnapshotId = $id
            $pre = @([pscustomobject]@{ ProcessName='pwsh'; Id=111; StartTime=(Get-Date) })
            $global:ConsoleWatchSnapshotPre = $pre
            InModuleScope ConsoleWatch {
                $script:ConsoleWatchState[$global:ConsoleWatchSnapshotId] = @{ Mode='snapshot'; OutDir=$global:ConsoleWatchSnapshotDir; Targets=@('pwsh'); Pre=$global:ConsoleWatchSnapshotPre }
            }
            Mock -CommandName Get-Process -ModuleName ConsoleWatch -MockWith {
                param([Parameter(ValueFromRemainingArguments=$true)][object[]]$Ignore)
                @(
                    [pscustomobject]@{ ProcessName='pwsh'; Id=111; StartTime=(Get-Date).AddSeconds(-5) },
                    [pscustomobject]@{ ProcessName='pwsh'; Id=222; StartTime=(Get-Date) }
                )
            }
            $summary = Stop-ConsoleWatch -Id $global:ConsoleWatchSnapshotId -OutDir $global:ConsoleWatchSnapshotDir -Phase 'post'
            $summary.counts.pwsh | Should -Be 1
            $summary.last[0].pid | Should -Be 222
            Remove-Variable -Name ConsoleWatchSnapshotDir,ConsoleWatchSnapshotPre,ConsoleWatchSnapshotId -Scope Global -ErrorAction SilentlyContinue
        }
    }
}

