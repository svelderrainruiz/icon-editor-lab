#Requires -Version 7.0
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = git rev-parse --show-toplevel
Push-Location $repoRoot
try {
  Write-Output '[pre-push] Running tools/PrePush-Checks.ps1'
  & "$repoRoot/tools/PrePush-Checks.ps1"
  if ($LASTEXITCODE -ne 0) {
    throw "PrePush-Checks.ps1 exited with code $LASTEXITCODE"
  }
} finally {
  Pop-Location
}

Write-Output '[pre-push] OK'

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