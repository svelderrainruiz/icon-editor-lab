#Requires -Version 7.0
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $PSCommandPath
$node = if ($env:HOOKS_NODE) { $env:HOOKS_NODE } else { 'node' }
$core = Join-Path $scriptRoot 'core' 'pre-push.mjs'

$nodePathLike = $node -match '[:\\/]'
if ($nodePathLike) {
  if (-not (Test-Path -LiteralPath $node -PathType Leaf)) {
    Write-Warning "[hooks] Node binary not executable at '$node'; skipping pre-push."
    exit 0
  }
} elseif (-not (Get-Command $node -ErrorAction SilentlyContinue)) {
  Write-Warning "[hooks] Node binary '$node' not found; skipping pre-push."
  exit 0
}

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $node
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $false
$psi.RedirectStandardError = $false
$psi.ArgumentList.Add($core)
$psi.WorkingDirectory = (git rev-parse --show-toplevel)

$process = [System.Diagnostics.Process]::Start($psi)
$process.WaitForExit()
exit $process.ExitCode

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