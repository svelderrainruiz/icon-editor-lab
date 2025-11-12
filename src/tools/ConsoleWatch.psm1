Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Variable -Name ConsoleWatchState -Scope Script -ErrorAction SilentlyContinue)) {
  $script:ConsoleWatchState = @{}
}
$script:ConsoleWatchInstrumentationEnabled = $true

function Write-ConsoleWatchRecord {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string[]]$TargetsLower,
    [Parameter(Mandatory)][int]$ProcessId,
    [Parameter(Mandatory)][string]$ProcessName,
    [Parameter(Mandatory)][int]$ParentProcessId
  )
  if (-not $ProcessName) { return $null }
  $normalized = $ProcessName.ToLowerInvariant()
  if ($TargetsLower -notcontains $normalized) { return $null }

  $meta = $null
  try { $meta = Get-CimInstance Win32_Process -Filter ("ProcessId={0}" -f $ProcessId) -ErrorAction SilentlyContinue } catch {}
  $cmd = if ($meta) { [string]$meta.CommandLine } else { $null }

  $parent = $null
  if ($ParentProcessId -gt 0) {
    try { $parent = Get-CimInstance Win32_Process -Filter ("ProcessId={0}" -f $ParentProcessId) -ErrorAction SilentlyContinue } catch {}
  }

  $hasWindow = $false
  try {
    $proc = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if ($proc) { $hasWindow = ($proc.MainWindowHandle -ne 0) }
  } catch { $hasWindow = $false }

  $record = [pscustomobject]@{
    ts         = (Get-Date).ToString('o')
    pid        = [int]$ProcessId
    name       = $ProcessName
    ppid       = [int]$ParentProcessId
    parentName = if ($parent) { [string]$parent.Name } else { $null }
    cmd        = $cmd
    hasWindow  = [bool]$hasWindow
  }

  try { $record | ConvertTo-Json -Compress | Add-Content -LiteralPath $Path -Encoding utf8 } catch {}
  return $record
}

function Invoke-ConsoleWatchEventRecord {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string[]]$TargetsLower,
    [Parameter(Mandatory)][int]$ProcessId,
    [Parameter(Mandatory)][string]$ProcessName,
    [int]$ParentProcessId
  )
  Write-ConsoleWatchRecord -Path $Path -TargetsLower $TargetsLower -ProcessId $ProcessId -ProcessName $ProcessName -ParentProcessId $ParentProcessId | Out-Null
}

<#
.SYNOPSIS
Start-ConsoleWatch: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Start-ConsoleWatch {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$OutDir,
    [string[]]$Targets = @('conhost','pwsh','powershell','cmd','wt'),
    [switch]$DisableInstrumentation
  )
    # ShouldProcess guard: honor -WhatIf / -Confirm
    if (-not $PSCmdlet.ShouldProcess($MyInvocation.MyCommand.Name, 'Execute')) { return }
  if ($DisableInstrumentation.IsPresent -or -not $script:ConsoleWatchInstrumentationEnabled) {
    return 'ConsoleWatch_disabled'
  }
  if (-not (Test-Path -LiteralPath $OutDir -PathType Container)) { try { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null } catch {} }
  $id = 'ConsoleWatch_' + ([guid]::NewGuid().ToString('n'))
  $ndjson = Join-Path $OutDir 'console-spawns.ndjson'
  $targetsLower = @($Targets | ForEach-Object { $_.ToLowerInvariant().Trim() } | Where-Object { $_ })
  # Ensure the NDJSON file exists even if no events occur (helps consumers and artifacts)
  try {
    if (-not (Test-Path -LiteralPath $ndjson -PathType Leaf)) { '' | Out-File -FilePath $ndjson -Encoding utf8 -ErrorAction SilentlyContinue }
  } catch {}
  try {
    Register-CimIndicationEvent -ClassName Win32_ProcessStartTrace -SourceIdentifier $id -Action {
      param($e)
      try {
        $event = $e.SourceEventArgs.NewEvent
        Invoke-ConsoleWatchEventRecord -Path $using:ndjson -TargetsLower $using:targetsLower -ProcessId $event.ProcessID -ProcessName ([string]$event.ProcessName) -ParentProcessId $event.ParentProcessID
      } catch {}
    } | Out-Null
    $script:ConsoleWatchState[$id] = @{ Mode='event'; OutDir=$OutDir; Targets=$targetsLower; Path=$ndjson }
    return $id
  } catch {
    $pre = @()
    try { $pre = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName.ToLowerInvariant() -in $targetsLower } | Select-Object ProcessName,Id,StartTime) } catch { $pre = @() }
    $script:ConsoleWatchState[$id] = @{ Mode='snapshot'; OutDir=$OutDir; Targets=$targetsLower; Pre=$pre }
    return $id
  }
}

<#
.SYNOPSIS
Stop-ConsoleWatch: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Stop-ConsoleWatch {
  [CmdletBinding()]
  param(
      [Parameter(Mandatory)][string]$Id,
      [Parameter(Mandatory)][string]$OutDir,
      [string]$Phase
  )
  if ($Id -eq 'ConsoleWatch_disabled') {
    $summary = [ordered]@{
      schema        = 'console-watch-summary/v1'
      phase         = $Phase
      generatedAtUtc= (Get-Date).ToUniversalTime().ToString('o')
      counts        = @{}
      last          = @()
      path          = (Join-Path $OutDir 'console-spawns.ndjson')
      disabled      = $true
    }
    try {
      $sumPath = Join-Path $OutDir 'console-watch-summary.json'
      $summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $sumPath -Encoding utf8
    } catch {}
    return $summary
  }
  $state = $script:ConsoleWatchState[$Id]
  if ($state.Mode -eq 'event') { try { Unregister-Event -SourceIdentifier $Id -ErrorAction SilentlyContinue } catch {}; try { Remove-Event -SourceIdentifier $Id -ErrorAction SilentlyContinue } catch {} }
  $summary = [ordered]@{ schema='console-watch-summary/v1'; phase=$Phase; generatedAtUtc=(Get-Date).ToUniversalTime().ToString('o'); counts=[ordered]@{}; last=@(); path=(Join-Path $OutDir 'console-spawns.ndjson') }
  try {
    $records = @()
    if ($state.Mode -eq 'event') {
      $nd = Join-Path $OutDir 'console-spawns.ndjson'
      if (Test-Path -LiteralPath $nd) {
        $lines = Get-Content -LiteralPath $nd -ErrorAction SilentlyContinue
        foreach ($ln in $lines) { try { $records += ($ln | ConvertFrom-Json) } catch {} }
      }
    } else {
      $pre = $state.Pre
      $post = @()
      try { $post = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName.ToLowerInvariant() -in $state.Targets } | Select-Object ProcessName,Id,StartTime) } catch { $post = @() }
      $preSet = @{}; foreach ($p in $pre) { $preSet[[string]$p.Id] = $true }
      foreach ($p in $post) { if (-not $preSet.ContainsKey([string]$p.Id)) { $records += [pscustomobject]@{ ts=(Get-Date).ToString('o'); pid=$p.Id; name=$p.ProcessName; ppid=$null; parentName=$null; cmd=$null; hasWindow=$null } } }
    }
    if ($records.Count -gt 0) {
      $byName = $records | Group-Object name | Sort-Object Name
      foreach ($g in $byName) { $summary.counts[$g.Name] = $g.Count }
      $summary.last = @($records | Select-Object -Last 3)
    }
  } catch {}
  try { $sumPath = Join-Path $OutDir 'console-watch-summary.json'; $summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $sumPath -Encoding utf8 } catch {}
  return $summary
}

Export-ModuleMember -Function Start-ConsoleWatch, Stop-ConsoleWatch

<#
.SYNOPSIS
Test-ValidLabel: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Test-ValidLabel {
  param([Parameter(Mandatory)][string]$Label)
  if ($Label -notmatch '^[A-Za-z0-9._-]{1,64}$') { throw "Invalid label: $Label" }
}

<#
.SYNOPSIS
Invoke-WithTimeout: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Invoke-WithTimeout {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][scriptblock]$ScriptBlock,
    [Parameter()][int]$TimeoutSec = 600
  )
  $job = Start-Job -ScriptBlock $ScriptBlock
  if (-not (Wait-Job $job -Timeout $TimeoutSec)) {
    try { Stop-Job $job -Force } catch {}
    throw "Operation timed out in $TimeoutSec s"
  }
  Receive-Job $job -ErrorAction Stop
}
