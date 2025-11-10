<#
.SYNOPSIS
  TODO: Brief synopsis for this tool function/script. (Auto-generated placeholder)
.DESCRIPTION
  TODO: Expand description. Replace this header with real help content.
#>

param(
  [ValidateSet('Start','End','Status')][string]$Action = 'End',
  [string]$Reason = 'unspecified',
  [int]$ExpectedSeconds = 90,
  [string]$ResultsDir = 'tests/results',
  [int]$ToleranceSeconds = 5,
  [string]$Id = 'default',
  [switch]$FailOnOutsideMargin
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

. (Join-Path $PSScriptRoot 'Agent-Wait.ps1')

switch ($Action) {
  'Start' {
    $marker = Start-AgentWait -Reason $Reason -ExpectedSeconds $ExpectedSeconds -ResultsDir $ResultsDir -ToleranceSeconds $ToleranceSeconds -Id $Id
    Write-Host ("Started wait marker: {0}" -f $marker)
    break
  }
  'End' {
    $res = End-AgentWait -ResultsDir $ResultsDir -ToleranceSeconds $ToleranceSeconds -Id $Id
    if ($null -eq $res) { exit 0 }
    $ok = $true
    if ($FailOnOutsideMargin.IsPresent -and -not [bool]$res.withinMargin) { $ok = $false }
    # Emit machine-friendly line
    Write-Output ("RESULT reason={0} elapsed={1}s expected={2}s tol={3}s diff={4}s within={5}" -f $res.reason,$res.elapsedSeconds,$res.expectedSeconds,$res.toleranceSeconds,$res.differenceSeconds,$res.withinMargin)
    if (-not $ok) { exit 2 } else { exit 0 }
  }
  'Status' {
    $outDir = Join-Path $ResultsDir '_agent'
    $sessionDir = Join-Path $outDir (Join-Path 'sessions' $Id)
    $markerPath = Join-Path $sessionDir 'wait-marker.json'
    $lastPath = Join-Path $sessionDir 'wait-last.json'
    if (Test-Path $lastPath) {
      $last = Get-Content $lastPath -Raw | ConvertFrom-Json
      Write-Output ("LAST reason={0} elapsed={1}s expected={2}s tol={3}s diff={4}s within={5}" -f $last.reason,$last.elapsedSeconds,$last.expectedSeconds,$last.toleranceSeconds,$last.differenceSeconds,$last.withinMargin)
    } elseif (Test-Path $markerPath) {
      $m = Get-Content $markerPath -Raw | ConvertFrom-Json
      Write-Output ("MARKER reason={0} expected={1}s tol={2}s started={3}" -f $m.reason,$m.expectedSeconds,$m.toleranceSeconds,$m.startedUtc)
    } else {
      Write-Host '::notice::No wait marker or last result found.'
    }
    break
  }
}

function Test-ValidLabel {
  param([Parameter(Mandatory)][string]$Label)
  if ($Label -notmatch '^[A-Za-z0-9._-]{1,64}$') { throw "Invalid label: $Label" }
}

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