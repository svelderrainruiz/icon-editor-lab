<#
.SYNOPSIS
  TODO: Brief synopsis for this tool function/script. (Auto-generated placeholder)
.DESCRIPTION
  TODO: Expand description. Replace this header with real help content.
#>

[CmdletBinding()]
param(
  [switch]$FailOnViolation
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$workflows = Get-ChildItem -Path (Join-Path (Get-Location).Path '.github/workflows') -Filter *.yml -File -ErrorAction SilentlyContinue
if (-not $workflows) {
  Write-Host 'No workflow files to lint.'
  exit 0
}

$pathsList = ($workflows | ForEach-Object { $_.FullName }) -join ';'

$args = @('-PathsList', $pathsList)
if ($FailOnViolation) { $args += '-FailOnViolation' }

& pwsh -NoLogo -NoProfile -File ./tools/Lint-LoopDeterminism.Shim.ps1 @args
exit $LASTEXITCODE

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