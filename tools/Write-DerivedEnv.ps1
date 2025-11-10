<#
.SYNOPSIS
  TODO: Brief synopsis for this tool function/script. (Auto-generated placeholder)
.DESCRIPTION
  TODO: Expand description. Replace this header with real help content.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$workspace = (Get-Location).Path
$outputPath = Join-Path $workspace 'derived-env.json'

Write-Host 'Deriving environment snapshot...'
$derive = & node tools/npm/run-script.mjs --silent derive:env 2>&1
if ($LASTEXITCODE -ne 0) {
  $derive | ForEach-Object { Write-Host $_ }
  Write-Error "node tools/npm/run-script.mjs derive:env failed with exit code $LASTEXITCODE"
  exit $LASTEXITCODE
}

if ($derive) {
  $derive | Set-Content -LiteralPath $outputPath -Encoding utf8
} else {
  Set-Content -LiteralPath $outputPath -Encoding utf8 -Value ''
}

$agentDir = Join-Path $workspace 'tests/results/_agent'
if (-not (Test-Path -LiteralPath $agentDir)) {
  New-Item -ItemType Directory -Force -Path $agentDir | Out-Null
}

$dest = Join-Path $agentDir 'derived-env.json'
Copy-Item -LiteralPath $outputPath -Destination $dest -Force
Write-Host "Wrote $dest"

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