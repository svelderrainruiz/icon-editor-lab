<#!
.SYNOPSIS
  Follow a metrics snapshots NDJSON file produced by -MetricsSnapshotPath and pretty-print selected fields.
.DESCRIPTION
  Reads appended JSON lines (schema metrics-snapshot-v2) and displays a rolling table of iteration, diffCount,
  errorCount, averageSeconds, and dynamic percentile keys.

  Intended for local developer ergonomics (not used in CI). Safe to stop/restart; maintains simple file position.
.PARAMETER Path
  Path to the NDJSON snapshot file.
.PARAMETER IntervalSeconds
  Poll interval when at EOF (default 1.5s).
.PARAMETER PercentileKeys
  Optional comma/space list of percentile labels to show (default: auto-detect from first object).
.EXAMPLE
  pwsh -File ./tools/Tail-Snapshots.ps1 -Path snapshots.ndjson
.EXAMPLE
  pwsh -File ./tools/Tail-Snapshots.ps1 -Path snapshots.ndjson -PercentileKeys p50,p90,p99
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Path,
  [double]$IntervalSeconds = 1.5,
  [string]$PercentileKeys
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSModuleAutoLoadingPreference = 'None'
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Snapshot file not found: $Path" }
$fs = [IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
$sr = New-Object IO.StreamReader($fs)
$pos = $fs.Length
$fs.Seek(0,[IO.SeekOrigin]::Begin) | Out-Null
$detectedKeys = $null
$customKeys = @()
if ($PercentileKeys) { $customKeys = $PercentileKeys -split '[, ]+' | Where-Object { $_ } }
Write-Host "Tailing snapshots: $Path" -ForegroundColor Cyan
while ($true) {
  $line = $sr.ReadLine()
  if ($null -eq $line) {
    Start-Sleep -Seconds $IntervalSeconds
    continue
  }
  if (-not $line.Trim()) { continue }
  try { $o = $line | ConvertFrom-Json } catch { continue }
  if (-not $o) { continue }
  if (-not $detectedKeys) {
    if ($o.percentiles) {
      $detectedKeys = @($o.percentiles | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Sort-Object)
    } else {
      $detectedKeys = @('p50','p90','p99')
    }
    if ($customKeys.Count -gt 0) { $detectedKeys = @($customKeys) }
    Write-Host ("Fields: iteration diffCount errorCount averageSeconds {0}" -f ($detectedKeys -join ' ')) -ForegroundColor DarkGray
  }
  $vals = @()
  foreach ($k in $detectedKeys) {
    $v = $null
    if ($o.percentiles -and ($o.percentiles.PSObject.Properties.Name -contains $k)) { $v = $o.percentiles.$k }
    elseif ($o.PSObject.Properties.Name -contains $k) { $v = $o.$k }
    else { $v = '' }
    $vals += $v
  }
  Write-Host ("{0,5} {1,3} {2,3} {3,7} {4}" -f $o.iteration,$o.diffCount,$o.errorCount,[string]::Format('{0:N3}',$o.averageSeconds),($vals -join ' '))
}

<#
.SYNOPSIS
Test-ValidLabel: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Test-ValidLabel {

    # ShouldProcess guard: honor -WhatIf / -Confirm
    if (-not $PSCmdlet.ShouldProcess($MyInvocation.MyCommand.Name, 'Execute')) { return }
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
