param(
  [Parameter(Mandatory)][string]$Requirement,
  [Parameter(Mandatory)][string]$AdrId
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

$repoRoot = (Resolve-Path '.').Path
$reqDir = Join-Path $repoRoot 'docs/requirements'
$adrDir = Join-Path $repoRoot 'docs/adr'
$adrIndexPath = Join-Path $adrDir 'README.md'

<#
.SYNOPSIS
Resolve-RequirementPath: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Resolve-RequirementPath {

    # ShouldProcess guard: honor -WhatIf / -Confirm
    if (-not $PSCmdlet.ShouldProcess($MyInvocation.MyCommand.Name, 'Execute')) { return }
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param([string]$Value)
  if ([IO.Path]::IsPathRooted($Value)) {
    return (Resolve-Path -LiteralPath $Value).Path
  }
  $candidate = Join-Path $reqDir $Value
  if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
  if (-not [IO.Path]::HasExtension($Value)) {
    $candidate = Join-Path $reqDir ($Value + '.md')
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
  }
  throw "Requirement file not found: $Value"
}

<#
.SYNOPSIS
Resolve-AdrFile: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Resolve-AdrFile {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param([string]$Id)
  $files = @(Get-ChildItem -LiteralPath $adrDir -File -Filter ($Id + '-*.md'))
  if ($files.Count -eq 0) { throw "ADR file not found for id $Id" }
  if ($files.Count -gt 1) { throw "Multiple ADR files found for id $Id" }
  return $files[0]
}

$reqPath = Resolve-RequirementPath -Value $Requirement
$reqName = [IO.Path]::GetFileNameWithoutExtension($reqPath)
$adrFile = Resolve-AdrFile -Id $AdrId
$adrFileName = $adrFile.Name

# Update requirement Traceability section.
$relativeAdrLink = [IO.Path]::GetRelativePath([IO.Path]::GetDirectoryName($reqPath), $adrFile.FullName).Replace('\','/')
$traceLine = "- Architectural Decision Record: [`ADR $AdrId`]($relativeAdrLink)"
$reqLines = @() + (Get-Content -LiteralPath $reqPath)
$hasTraceHeader = $false
$traceIndex = -1
for ($i = 0; $i -lt $reqLines.Count; $i++) {
  if ($reqLines[$i] -match '^\s*##\s*Traceability\s*$') { $hasTraceHeader = $true; $traceIndex = $i; break }
}
if (-not $hasTraceHeader) {
  if ($reqLines.Count -gt 0 -and $reqLines[-1].Trim().Length -ne 0) { $reqLines += '' }
  $reqLines += '## Traceability'
  $reqLines += ''
  $reqLines += $traceLine
} elseif ($reqLines -notcontains $traceLine) {
  $insertIndex = $traceIndex + 1
  while ($insertIndex -lt $reqLines.Count -and $reqLines[$insertIndex].Trim().Length -eq 0) { $insertIndex++ }
  if ($insertIndex -ge $reqLines.Count) {
    if ($reqLines.Count -gt 0 -and $reqLines[-1].Trim().Length -ne 0) { $reqLines += '' }
    $reqLines += $traceLine
  } elseif ($insertIndex -eq 0) {
    $reqLines = @($traceLine) + $reqLines
  } else {
    $reqLines = $reqLines[0..($insertIndex-1)] + @($traceLine) + $reqLines[$insertIndex..($reqLines.Count-1)]
  }
}
Set-Content -LiteralPath $reqPath -Value $reqLines -Encoding utf8

# Update ADR References section.
$reqRelativeFromAdr = [IO.Path]::GetRelativePath($adrDir, $reqPath).Replace('\','/')
$adrRequirementLine = "- [`$reqName`](../$reqRelativeFromAdr)"
$adrLines = @() + (Get-Content -LiteralPath $adrFile.FullName)
if ($adrLines -notcontains $adrRequirementLine) {
$referencesIndex = -1
for ($i = 0; $i -lt $adrLines.Count; $i++) {
  if ($adrLines[$i].Trim() -eq '## References') { $referencesIndex = $i; break }
}
if ($referencesIndex -lt 0) { throw "ADR missing References section: $($adrFile.FullName)" }
  $insertIndex = $referencesIndex + 1
  while ($insertIndex -lt $adrLines.Count -and $adrLines[$insertIndex].Trim() -eq '') { $insertIndex++ }
  if ($insertIndex -ge $adrLines.Count) {
    $adrLines += ''
    $adrLines += $adrRequirementLine
  } else {
    $adrLines = $adrLines[0..($insertIndex-1)] + @($adrRequirementLine) + $adrLines[$insertIndex..($adrLines.Count-1)]
  }
  Set-Content -LiteralPath $adrFile.FullName -Value $adrLines -Encoding utf8
}

# Update ADR index table.
if (-not (Test-Path -LiteralPath $adrIndexPath -PathType Leaf)) {
  throw "ADR index not found: $adrIndexPath"
}
$indexLines = @() + (Get-Content -LiteralPath $adrIndexPath)
$rowIndex = -1
for ($i = 0; $i -lt $indexLines.Count; $i++) {
  if ($indexLines[$i] -match "^\|\s*\[$AdrId\]") { $rowIndex = $i; break }
}
if ($rowIndex -ge 0) {
  $row = $indexLines[$rowIndex]
  $reqLink = "[`$reqName`](../$reqRelativeFromAdr)"
  if ($row -notmatch [regex]::Escape($reqLink)) {
    $parts = $row.Split('|')
    $reqCellIndex = $parts.Length - 2
    $cell = $parts[$reqCellIndex].Trim()
    if ($cell -eq '_TBD_' -or [string]::IsNullOrWhiteSpace($cell)) {
      $cell = $reqLink
    } else {
      $cell = "$cell, $reqLink"
    }
    $parts[$reqCellIndex] = " $cell "
    $indexLines[$rowIndex] = ($parts -join '|')
    Set-Content -LiteralPath $adrIndexPath -Value $indexLines -Encoding utf8
  }
}

Write-Host ("Linked requirement '{0}' to ADR {1}" -f $reqName, $AdrId) -ForegroundColor Green

<#
.SYNOPSIS
Test-ValidLabel: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Test-ValidLabel {
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