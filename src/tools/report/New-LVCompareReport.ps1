Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSModuleAutoLoadingPreference = 'None'
#Requires -Version 7.0
[CmdletBinding()]
param(
  [string]$Label = ("lvcompare-{0}" -f (Get-Date -Format 'yyyyMMddTHHmmss')),
  [string]$Command = "<paste command>",
  [string]$Transcript = "<path>",
  [string]$Telemetry = "<session-index path>",
  [string]$Summary = "<paste summary block>",
  [string]$Warnings = "<warnings/errors>"
)

$lines = @(
  "### LVCompare Suite (Label: $Label)",
  "- Command: ``$Command``",
  "- Summary:",
  '```',
  $Summary,
  '```',
  "- Transcript: $Transcript",
  "- Telemetry: $Telemetry",
  "- Warnings/Errors:",
  '```',
  $Warnings,
  '```'
)

$lines -join [Environment]::NewLine

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