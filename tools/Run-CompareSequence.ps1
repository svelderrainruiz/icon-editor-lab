Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSModuleAutoLoadingPreference = 'None'
param(
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
param(
  [Parameter()][ValidateSet('2021','2023','2025')][string]$LabVIEWVersion = '2023',
  [Parameter()][ValidateSet(32,64)][int]$Bitness = 64,
  [Parameter()][ValidateNotNullOrEmpty()][string]$Workspace = (Get-Location).Path,
  [Parameter()][int]$TimeoutSec = 600
)
  [string]$Base,
  [string]$Head,
  [string]$SeqId,
  [switch]$Verify,
  [switch]$Render,
  [switch]$Telemetry
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $SeqId) { $SeqId = (Get-Date -Format 'yyyyMMdd-HHmmss') }
$root = (Get-Location).Path
$outDir = Join-Path $root (Join-Path 'results' $SeqId)
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

# Local lock (filesystem) to emulate 4-wire control
$lockPath = Join-Path $outDir '.lock'
$lock = $null
try {
  $lock = [System.IO.File]::Open($lockPath,[System.IO.FileMode]::OpenOrCreate,[System.IO.FileAccess]::ReadWrite,[System.IO.FileShare]::None)
} catch {
  throw "Sequence is busy (lock held): $SeqId"
}

try {
  # Pass 1: Compare → compare-exec.json
  if ($Base -and $Head) {
    Import-Module (Join-Path $root 'scripts' 'CompareVI.psm1') -Force
    $execPath = Join-Path $outDir 'compare-exec.json'
    Write-Host "[seq:$SeqId] Compare -> $execPath"
    Invoke-CompareVI -Base $Base -Head $Head -CompareExecJsonPath $execPath | Out-Null
  }

  # Pass 2: Verify (content/fixture) — read-only w.r.t. CLI
  if ($Verify.IsPresent) {
    $execPath = Join-Path $outDir 'compare-exec.json'
    if (-not (Test-Path -LiteralPath $execPath)) { throw 'compare-exec.json missing for Verify' }
    Write-Host "[seq:$SeqId] Verify"
    pwsh -NoLogo -NoProfile -File (Join-Path $root 'tools' 'Verify-FixtureCompare.ps1') -ExecJsonPath $execPath -ResultsDir $outDir -VerboseOutput | Out-Null
  }

  # Pass 3: Render (HTML + signature) — read-only
  if ($Render.IsPresent) {
    $execPath = Join-Path $outDir 'compare-exec.json'
    if (-not (Test-Path -LiteralPath $execPath)) { throw 'compare-exec.json missing for Render' }
    $report = Join-Path $outDir 'compare-report.html'
    Write-Host "[seq:$SeqId] Render -> $report"
    pwsh -NoLogo -NoProfile -File (Join-Path $root 'scripts' 'Render-CompareReport.ps1') -ExecJsonPath $execPath -OutputPath $report | Out-Null
  }

  # Pass 4: Telemetry (rogue detector)
  if ($Telemetry.IsPresent) {
    Write-Host "[seq:$SeqId] Telemetry"
    $rogue = pwsh -NoLogo -NoProfile -File (Join-Path $root 'tools' 'Detect-RogueLV.ps1') -ResultsDir $outDir -LookBackSeconds 900 -Quiet
    if ($rogue) { $rogue | Out-File -FilePath (Join-Path $outDir 'rogue-lv-detection.json') -Encoding utf8 }
  }
}
finally {
  if ($lock) { $lock.Dispose() }
}

Write-Host "[seq:$SeqId] Done -> $outDir"


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