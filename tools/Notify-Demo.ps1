<#
.SYNOPSIS
  TODO: Brief synopsis for this tool function/script. (Auto-generated placeholder)
.DESCRIPTION
  TODO: Expand description. Replace this header with real help content.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSModuleAutoLoadingPreference = 'None'
param(
  [string]$Status,
  [int]$Failed,
  [int]$Tests,
  [int]$Skipped,
  [int]$RunSequence,
  [string]$Classification
)
# Simple demo notify script. Writes a concise line plus environment reflection.
$line = "Notify: Run#$RunSequence Status=$Status Failed=$Failed Tests=$Tests Skipped=$Skipped Class=$Classification"
Write-Output $line
if ($env:WATCH_STATUS) {
  Write-Output "Env WATCH_STATUS=$($env:WATCH_STATUS)"
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