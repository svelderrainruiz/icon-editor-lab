Set-StrictMode -Version Latest
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
param(
  [Parameter()][ValidateSet('2021','2023','2025')][string]$LabVIEWVersion = '2023',
  [Parameter()][ValidateSet(32,64)][int]$Bitness = 64,
  [Parameter()][ValidateNotNullOrEmpty()][string]$Workspace = (Get-Location).Path,
  [Parameter()][int]$TimeoutSec = 600
)
$ErrorActionPreference = 'Stop'
$PSModuleAutoLoadingPreference = 'None'
<#!
.SYNOPSIS
  Computes a delta between two fixture validation JSON outputs.
.DESCRIPTION
  Compares baseline and current fixture-validation JSON (from Validate-Fixtures.ps1 -Json) and emits a delta JSON with changed counts and newly appearing structural issues.
.PARAMETER Baseline  Path to prior run fixture-validation.json (baseline); must exist.
.PARAMETER Current   Path to current run fixture-validation.json; must exist.
.PARAMETER Output    Optional output file path; if omitted, JSON printed to stdout.
.PARAMETER FailOnNewStructuralIssue Exit non-zero (3) if new structural issue types appear.
.PARAMETER Verbose   Emits diagnostic traces to stderr via Write-Verbose (standard PowerShell flag).
.EXITCODES
  0 success / no disallowed new structural issues (or none requested)
  2 invalid input (missing files, parse errors)
  3 new disallowed structural issues introduced
#>
param(
  [Parameter(Mandatory)][string]$Baseline,
  [Parameter(Mandatory)][string]$Current,
  [string]$Output,
  [switch]$FailOnNewStructuralIssue,
  [switch]$UseV2Schema # if set (or env DELTA_SCHEMA_VERSION=v2) emit fixture-validation-delta-v2 with bounded validation expectations
)

${ErrorActionPreference} = 'Stop'

# Honor -Verbose common parameter if provided
if ($PSBoundParameters.ContainsKey('Verbose')) { $VerbosePreference = 'Continue' }

function Read-JsonStrict([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { throw "File not found: $path" }
  try { return (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -ErrorAction Stop) }
  catch { throw "Failed to parse JSON: $path :: $($_.Exception.Message)" }
}

try {
  Write-Verbose "Reading baseline: $Baseline"
  $base = Read-JsonStrict $Baseline
  Write-Verbose "Reading current : $Current"
  $curr = Read-JsonStrict $Current
} catch {
  Write-Error $_.Exception.Message
  exit 2
}

$cats = 'missing','untracked','tooSmall','hashMismatch','manifestError','duplicate','schema'

<#
.SYNOPSIS
Get-IssueCount: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Get-IssueCount {

    # ShouldProcess guard: honor -WhatIf / -Confirm
    if (-not $PSCmdlet.ShouldProcess($MyInvocation.MyCommand.Name, 'Execute')) { return }
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param($obj,[string]$cat)
  # Prefer summaryCounts if present
  if ($obj.PSObject.Properties.Name -contains 'summaryCounts') {
    $val = $obj.summaryCounts.$cat
    if ($null -ne $val) { return [int]$val }
  }
  # Fallback: derive from issues list
  if ($obj.PSObject.Properties.Name -contains 'issues' -and $obj.issues) {
    return (@($obj.issues | Where-Object { $_.type -eq $cat })).Count
  }
  return 0
}

$baseCounts = @{}
$currCounts = @{}
foreach ($c in $cats) {
  $baseCounts[$c] = Get-IssueCount $base $c
  $currCounts[$c] = Get-IssueCount $curr $c
}
Write-Verbose ("Base counts: {0}" -f ([string]::Join(',',($baseCounts.GetEnumerator() | ForEach-Object { "{0}={1}" -f $_.Key,$_.Value }))))
Write-Verbose ("Curr counts: {0}" -f ([string]::Join(',',($currCounts.GetEnumerator() | ForEach-Object { "{0}={1}" -f $_.Key,$_.Value }))))

$deltaCounts = [ordered]@{}
$changeList = @()
foreach ($c in $cats) {
  $delta = $currCounts[$c] - $baseCounts[$c]
  if ($delta -ne 0) {
    $deltaCounts[$c] = $delta
    $changeList += [pscustomobject]@{ category=$c; baseline=$baseCounts[$c]; current=$currCounts[$c]; delta=$delta }
  }
}

# Detect newly appearing structural issues (excluding 'tooSmall')
$structural = 'missing','untracked','hashMismatch','manifestError','duplicate','schema'
$newStructural = @($changeList | Where-Object { $_.category -in $structural -and $_.baseline -eq 0 -and $_.current -gt 0 })

$schemaVersion = 'fixture-validation-delta-v1'
if ($env:DELTA_FORCE_V2 -eq 'true') { $schemaVersion = 'fixture-validation-delta-v2' }
elseif ($UseV2Schema -or $env:DELTA_SCHEMA_VERSION -eq 'v2') { $schemaVersion = 'fixture-validation-delta-v2' }

$result = [ordered]@{
  schema = $schemaVersion
  baselinePath = $Baseline
  currentPath = $Current
  generatedAt = (Get-Date).ToString('o')
  baselineOk = $base.ok
  currentOk = $curr.ok
  deltaCounts = $deltaCounts
  changes = $changeList
  newStructuralIssues = $newStructural
  failOnNewStructuralIssue = [bool]$FailOnNewStructuralIssue
  willFail = ($FailOnNewStructuralIssue -and $newStructural.Count -gt 0)
}

$json = $result | ConvertTo-Json -Depth 6
Write-Verbose "Delta willFail=$($result.willFail) structuralNew=$($newStructural.Count)"
if ($Output) { Set-Content -LiteralPath $Output -Value $json -Encoding utf8 } else { Write-Output $json }

if ($result.willFail) { exit 3 }
exit 0

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