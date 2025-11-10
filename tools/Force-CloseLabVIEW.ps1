param(
  [string[]]$ProcessName = @('LabVIEW','LVCompare'),
  [switch]$DryRun,
  [int]$WaitSeconds = 5,
  [switch]$Quiet
)

Set-StrictMode -Version Latest
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
param(
  [Parameter()][ValidateSet('2021','2023','2025')][string]$LabVIEWVersion = '2023',
  [Parameter()][ValidateSet(32,64)][int]$Bitness = 64,
  [Parameter()][ValidateNotNullOrEmpty()][string]$Workspace = (Get-Location).Path,
  [Parameter()][int]$TimeoutSec = 600
)
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Write-Info: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Write-Info {

    # ShouldProcess guard: honor -WhatIf / -Confirm
    if (-not $PSCmdlet.ShouldProcess($MyInvocation.MyCommand.Name, 'Execute')) { return }
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param([string]$Message)
  if (-not $Quiet) { Write-Host $Message -ForegroundColor DarkGray }
}

<#
.SYNOPSIS
Write-Warn: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Write-Warn {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param([string]$Message)
  Write-Warning $Message
}

$names = @()
foreach ($name in $ProcessName) {
  if (-not [string]::IsNullOrWhiteSpace($name)) {
    $names += $name.Trim()
  }
}
if ($names.Count -eq 0) {
  Write-Warn 'No process names supplied; nothing to do.'
  exit 0
}

$initial = @()
foreach ($name in $names) {
  try {
    $initial += @(Get-Process -Name $name -ErrorAction SilentlyContinue)
  } catch {}
}

if ($initial.Count -eq 0) {
  Write-Info ("Force-CloseLabVIEW: no matching processes found for {0}." -f ($names -join ','))
  exit 0
}

$summary = [ordered]@{
  schema    = 'force-close-labview/v1'
  generated = (Get-Date).ToString('o')
  dryRun    = $DryRun.IsPresent
  targets   = @(
    $initial | Select-Object @{n='name';e={$_.ProcessName}}, @{n='pid';e={$_.Id}}
  )
}

if ($DryRun) {
  $summary['result'] = 'skipped'
  $summary | ConvertTo-Json -Depth 4 | Write-Output
  exit 0
}

$errors = New-Object System.Collections.Generic.List[string]
foreach ($proc in $initial) {
  try {
    Stop-Process -Id $proc.Id -Force -ErrorAction Stop
    Write-Info ("Force-CloseLabVIEW: terminated {0} (PID {1})." -f $proc.ProcessName, $proc.Id)
  } catch {
    $msg = ("Force-CloseLabVIEW: failed to terminate {0} (PID {1}): {2}" -f $proc.ProcessName, $proc.Id, $_.Exception.Message)
    $errors.Add($msg)
    Write-Warn $msg
  }
}

$deadline = (Get-Date).AddSeconds([Math]::Max(0,$WaitSeconds))
do {
  $remaining = @()
  foreach ($name in $names) {
    try {
      $remaining += @(Get-Process -Name $name -ErrorAction SilentlyContinue)
    } catch {}
  }
  if ($remaining.Count -eq 0) { break }
  Start-Sleep -Milliseconds 250
} while ((Get-Date) -lt $deadline)

$summary['errors'] = @($errors)
$summary['remaining'] = @(
  $remaining | Select-Object @{n='name';e={$_.ProcessName}}, @{n='pid';e={$_.Id}}
)

if ($remaining.Count -eq 0 -and $errors.Count -eq 0) {
  $summary['result'] = 'success'
  $summary | ConvertTo-Json -Depth 4 | Write-Output
  exit 0
}

if ($remaining.Count -gt 0) {
  Write-Warn ("Force-CloseLabVIEW: processes still running: {0}" -f ($remaining | ForEach-Object { "{0}(PID {1})" -f $_.ProcessName,$_.Id } | Sort-Object | -join ', '))
}

$summary['result'] = 'failed'
$summary | ConvertTo-Json -Depth 4 | Write-Output
exit 1

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