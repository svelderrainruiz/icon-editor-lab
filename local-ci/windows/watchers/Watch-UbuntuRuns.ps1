#Requires -Version 7.0
<#
.SYNOPSIS
  Watches `out/local-ci-ubuntu/` for new Ubuntu local CI runs and automatically
  starts the Windows local CI import/LabVIEW stages.

.DESCRIPTION
  Polls the Ubuntu runs directory (accessible from Windows), looks for new
  folders containing `ubuntu-run.json`, and invokes
  `local-ci/windows/scripts/Start-ImportedRun.ps1` for each unseen run.
  Writes watcher logs and summary JSON files under `out/local-ci-windows/watchers/`.

.PARAMETER RunsRoot
  Path to the Ubuntu runs directory (`out/local-ci-ubuntu`). Defaults to the
  repo-relative path.

.PARAMETER LogRoot
  Directory where watcher logs/summaries are saved. Defaults to
  `out/local-ci-windows/watchers`.

.PARAMETER IntervalSeconds
  Polling interval between checks when no new runs are found. Default: 30 seconds.

.PARAMETER DebounceSeconds
  Delay applied after detecting a new manifest before importing, to ensure files
  are fully written. Default: 5 seconds.

.PARAMETER Once
  Process pending runs (if any) and exit instead of running continuously.

.PARAMETER DryRun
  Log discoveries but skip invoking the Windows local CI.
#>
[CmdletBinding()]
param(
    [string]$RunsRoot,
    [string]$LogRoot,
    [int]$IntervalSeconds = 30,
    [int]$DebounceSeconds = 5,
    [switch]$Once,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSModuleAutoLoadingPreference = 'None'

function Resolve-RepoRoot {
    param([string]$Start = $PSScriptRoot)
    try {
        $resolved = git -C $Start rev-parse --show-toplevel 2>$null
        if ($resolved) { return $resolved.Trim() }
    } catch {}
    return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..' '..')).Path
}

$repoRoot = Resolve-RepoRoot
if (-not $RunsRoot) {
    $RunsRoot = Join-Path $repoRoot 'out/local-ci-ubuntu'
}
if (-not $LogRoot) {
    $LogRoot = Join-Path $repoRoot 'out/local-ci-windows/watchers'
}

$runsRootResolved = Resolve-Path -LiteralPath $RunsRoot -ErrorAction Stop
$logRootResolved = (New-Item -ItemType Directory -Path $LogRoot -Force).FullName
$statePath = Join-Path $logRootResolved 'watcher-state.json'

if ($IntervalSeconds -lt 1) { $IntervalSeconds = 1 }
if ($DebounceSeconds -lt 0) { $DebounceSeconds = 0 }

function Read-WatcherState {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return @{ lastImportedRun = $null }
    }
    try {
        $json = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
        return (ConvertFrom-Json -InputObject $json -ErrorAction Stop)
    } catch {
        Write-Warning "Failed to read watcher state ($($_.Exception.Message)); starting fresh."
        return @{ lastImportedRun = $null }
    }
}

function Write-WatcherState {
    param([string]$Path, [string]$RunName)
    $payload = @{ lastImportedRun = $RunName }
    $payload | ConvertTo-Json | Set-Content -LiteralPath $Path -Encoding utf8
}

function Get-PendingRunDirs {
    param(
        [string]$Root,
        [string]$LastImportedName
    )
    $dirs = Get-ChildItem -LiteralPath $Root -Directory -ErrorAction Stop | Sort-Object Name
    foreach ($dir in $dirs) {
        $manifest = Join-Path $dir.FullName 'ubuntu-run.json'
        $ready = Join-Path $dir.FullName '_READY'
        $done = Join-Path $dir.FullName '_DONE'
        $claimed = Join-Path $dir.FullName 'windows.claimed'
        if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) { continue }
        if (-not (Test-Path -LiteralPath $ready -PathType Leaf)) { continue }
        if (Test-Path -LiteralPath $done -PathType Leaf) { continue }
        if (Test-Path -LiteralPath $claimed -PathType Leaf) { continue }
        $name = $dir.Name
        if ($LastImportedName -and ($name -le $LastImportedName)) { continue }
        [pscustomobject]@{
            Name     = $name
            FullPath = $dir.FullName
            Manifest = $manifest
        }
    }
}

function New-WatcherLog {
    param([string]$Root, [string]$RunName)
    $stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
    $logDir = Join-Path $Root $stamp
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    $logPath = Join-Path $logDir 'watcher.log'
    $summaryPath = Join-Path $logDir 'summary.json'
    return [pscustomobject]@{
        Directory   = $logDir
        LogPath     = $logPath
        SummaryPath = $summaryPath
        RunName     = $RunName
    }
}

function Write-LogLine {
    param(
        [string]$Path,
        [string]$Message
    )
    $line = "[{0}] {1}" -f (Get-Date).ToString('u'), $Message
    $line | Tee-Object -FilePath $Path -Append
}

$state = Read-WatcherState -Path $statePath
$startScript = Join-Path $PSScriptRoot '..' 'scripts' 'Start-ImportedRun.ps1'
$startScriptResolved = Resolve-Path -LiteralPath $startScript -ErrorAction Stop

Write-Host "Watching Ubuntu runs under $runsRootResolved"

function Process-Run {
    param(
        [pscustomobject]$RunInfo,
        [string]$LogRootPath,
        [switch]$DryMode,
        [int]$DebounceSeconds
    )
    $logSession = New-WatcherLog -Root $LogRootPath -RunName $RunInfo.Name
    Write-LogLine -Path $logSession.LogPath -Message "Detected new run $($RunInfo.FullPath)"

    Start-Sleep -Seconds $DebounceSeconds

    $manifestData = $null
    try {
        $manifestData = Get-Content -LiteralPath $RunInfo.Manifest -Raw | ConvertFrom-Json -ErrorAction Stop
        Write-LogLine -Path $logSession.LogPath -Message "Manifest parsed (commit: $($manifestData.git.commit))"
    } catch {
        Write-LogLine -Path $logSession.LogPath -Message "Failed to parse manifest: $($_.Exception.Message)"
    }

    $claimPath = Join-Path $RunInfo.FullPath 'windows.claimed'

    $result = @{
        watcher       = 'Watch-UbuntuRuns'
        runName       = $RunInfo.Name
        runPath       = $RunInfo.FullPath
        startedAtUtc  = (Get-Date).ToUniversalTime().ToString('o')
        dryRun        = [bool]$DryMode
        manifest      = $manifestData
        importExitCode= $null
        completedAtUtc= $null
        claimPath     = $null
    }

    if ($DryMode) {
        Write-LogLine -Path $logSession.LogPath -Message "[DRY RUN] Skipping Start-ImportedRun.ps1"
        $result.completedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        $result.importExitCode = 0
        $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $logSession.SummaryPath -Encoding utf8
        return $result
    }

    $claimPayload = [ordered]@{
        watcher       = 'Watch-UbuntuRuns'
        machine       = $env:COMPUTERNAME
        claimedAtUtc  = (Get-Date).ToUniversalTime().ToString('o')
        debounceSeconds = $DebounceSeconds
    }
    $claimPayload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $claimPath -Encoding utf8
    $result.claimPath = $claimPath

    Write-LogLine -Path $logSession.LogPath -Message "Invoking Start-ImportedRun.ps1 for $($RunInfo.FullPath)"
    & $startScriptResolved -UbuntuRunPath $RunInfo.FullPath 2>&1 | Tee-Object -FilePath $logSession.LogPath -Append
    $exitCode = $LASTEXITCODE
    $result.importExitCode = $exitCode
    $result.completedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $logSession.SummaryPath -Encoding utf8

    if ($exitCode -eq 0) {
        Write-LogLine -Path $logSession.LogPath -Message "Import succeeded."
    } else {
        Write-LogLine -Path $logSession.LogPath -Message "Import failed with exit code $exitCode"
        Remove-Item -LiteralPath $claimPath -Force -ErrorAction SilentlyContinue
    }
    return $result
}

do {
    $pending = @(Get-PendingRunDirs -Root $runsRootResolved -LastImportedName $state.lastImportedRun)
    if ($pending.Count -eq 0) {
        if ($Once) { break }
        Start-Sleep -Seconds $IntervalSeconds
        continue
    }

    foreach ($run in $pending) {
        $result = Process-Run -RunInfo $run -LogRootPath $logRootResolved -DryMode:$DryRun -DebounceSeconds $DebounceSeconds
        if (-not $DryRun -and $result.importExitCode -eq 0) {
            $state.lastImportedRun = $run.Name
            Write-WatcherState -Path $statePath -RunName $run.Name
        }
        if ($Once) { break }
    }

} while (-not $Once)

Write-Host "Watcher exiting."
