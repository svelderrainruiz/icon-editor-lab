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