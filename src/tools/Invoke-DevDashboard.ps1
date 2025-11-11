param(
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
param(
  [Parameter()][ValidateSet('2021','2023','2025')][string]$LabVIEWVersion = '2023',
  [Parameter()][ValidateSet(32,64)][int]$Bitness = 64,
  [Parameter()][ValidateNotNullOrEmpty()][string]$Workspace = (Get-Location).Path,
  [Parameter()][int]$TimeoutSec = 600
)
  [string]$Group = 'pester-selfhosted',
  [string]$ResultsRoot = (Join-Path (Resolve-Path '.').Path 'tests/results'),
  [string]$OutputRoot = (Join-Path (Resolve-Path '.').Path 'tests/results/dev-dashboard'),
  [switch]$JsonOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $OutputRoot)) {
  New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
}

$cliPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Dev-Dashboard.ps1'
$htmlPath = Join-Path $OutputRoot 'dashboard.html'
$jsonPath = Join-Path $OutputRoot 'dashboard.json'

$argsHashtable = @{
  Group        = $Group
  ResultsRoot  = $ResultsRoot
  Quiet        = $true
  Json         = $true
}
if (-not $JsonOnly) {
  $argsHashtable['Html'] = $true
  $argsHashtable['HtmlPath'] = $htmlPath
}

$json = & $cliPath @argsHashtable
$json | Out-File -FilePath $jsonPath -Encoding utf8

if ($JsonOnly) {
  Write-Host "Dashboard JSON saved to $jsonPath"
} else {
  Write-Host "Dashboard HTML saved to $htmlPath"
  Write-Host "Dashboard JSON saved to $jsonPath"
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