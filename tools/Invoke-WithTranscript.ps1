<#
.SYNOPSIS
  TODO: Brief synopsis for this tool function/script. (Auto-generated placeholder)
.DESCRIPTION
  TODO: Expand description. Replace this header with real help content.
#>

#Requires -Version 7.0
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Label,
  [Parameter(Mandatory)][string]$Command,
  [string[]]$Arguments,
  [string]$WorkingDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
  param([string]$StartPath = (Get-Location).Path)
  try {
    $root = git -C $StartPath rev-parse --show-toplevel 2>$null
    if ($root) {
      return (Resolve-Path -LiteralPath $root.Trim()).Path
    }
  } catch {}
  return (Resolve-Path -LiteralPath $StartPath).Path
}

$repoRoot = Resolve-RepoRoot -StartPath (Split-Path -Parent $PSCommandPath)
$logsDir = Join-Path $repoRoot 'tests/results/_agent/logs'
if (-not (Test-Path -LiteralPath $logsDir -PathType Container)) {
  [void](New-Item -ItemType Directory -Path $logsDir -Force)
}

$sanitizedLabel = $Label -replace '[^a-zA-Z0-9_-]', '-'
if ([string]::IsNullOrWhiteSpace($sanitizedLabel)) {
  $sanitizedLabel = 'log'
}
$timestamp = Get-Date -Format 'yyyyMMddTHHmmssfff'
$logPath = Join-Path $logsDir ("{0}-{1}.log" -f $sanitizedLabel, $timestamp)

Write-Host ("[transcript] Saving output to {0}" -f $logPath) -ForegroundColor DarkGray

$exitCode = 0
$caughtError = $null
$previousInvocationLog = [System.Environment]::GetEnvironmentVariable('INVOCATION_LOG_PATH')
[System.Environment]::SetEnvironmentVariable('INVOCATION_LOG_PATH', $logPath)
Start-Transcript -Path $logPath -Force | Out-Null
try {
  if ($WorkingDirectory) {
    Push-Location -LiteralPath $WorkingDirectory
  }
  & $Command @Arguments
  if ($LASTEXITCODE -ne $null) {
    $exitCode = $LASTEXITCODE
  }
} catch {
  $caughtError = $_
  if ($LASTEXITCODE -ne $null -and $LASTEXITCODE -ne 0) {
    $exitCode = $LASTEXITCODE
  } else {
    $exitCode = 1
  }
} finally {
  [System.Environment]::SetEnvironmentVariable('INVOCATION_LOG_PATH', $previousInvocationLog)
  if ($WorkingDirectory) {
    Pop-Location
  }
  try { Stop-Transcript | Out-Null } catch {}
  Write-Host ("[transcript] Log captured at {0}" -f $logPath) -ForegroundColor DarkGray
}

Write-Host ("logPath={0}" -f $logPath)

if ($caughtError) {
  throw $caughtError
}

exit $exitCode

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