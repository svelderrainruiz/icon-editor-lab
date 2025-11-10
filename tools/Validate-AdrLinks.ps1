param(
  [string]$RequirementsDir = 'docs/requirements',
  [string]$AdrDir = 'docs/adr'
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

$root = (Resolve-Path '.').Path
$reqPath = if ([IO.Path]::IsPathRooted($RequirementsDir)) { $RequirementsDir } else { Join-Path $root $RequirementsDir }
$adrPath = if ([IO.Path]::IsPathRooted($AdrDir)) { $AdrDir } else { Join-Path $root $AdrDir }

if (-not (Test-Path -LiteralPath $reqPath -PathType Container)) {
  Write-Error "Requirements directory not found: $reqPath"
  exit 1
}
if (-not (Test-Path -LiteralPath $adrPath -PathType Container)) {
  Write-Error "ADR directory not found: $adrPath"
  exit 1
}

$adrFiles = Get-ChildItem -LiteralPath $adrPath -File -Filter '*.md' -ErrorAction Stop
$adrNames = $adrFiles | ForEach-Object { $_.Name }

$requirements = Get-ChildItem -LiteralPath $reqPath -File -Filter '*.md' -Recurse -ErrorAction Stop
$errors = New-Object System.Collections.Generic.List[string]

foreach ($req in $requirements) {
  $content = Get-Content -LiteralPath $req.FullName -Raw
  if ($content -notmatch '##\s*Traceability') {
    continue
  }
  $matches = [regex]::Matches($content, '\.\./adr/(?<file>[0-9A-Za-z\-_]+\.md)')
  if ($matches.Count -eq 0) {
    $errors.Add("Requirement missing ADR reference: $($req.FullName)") | Out-Null
    continue
  }
  foreach ($match in $matches) {
    $file = $match.Groups['file'].Value
    if ($adrNames -notcontains $file) {
      $errors.Add("Requirement references missing ADR '$file' in $($req.FullName)") | Out-Null
    }
  }
}

if ($errors.Count -gt 0) {
  Write-Host 'ADR link validation failed:' -ForegroundColor Red
  $errors | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
  exit 1
}

Write-Host 'ADR link validation passed.' -ForegroundColor Green
exit 0

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