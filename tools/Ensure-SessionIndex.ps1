param(
  [Parameter(Mandatory=$false)] [string]$ResultsDir = 'tests/results',
  [Parameter(Mandatory=$false)] [string]$SummaryJson = 'pester-summary.json'
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

try {
  if (-not (Test-Path -LiteralPath $ResultsDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $ResultsDir | Out-Null
  }
  $idxPath = Join-Path $ResultsDir 'session-index.json'
  if (Test-Path -LiteralPath $idxPath -PathType Leaf) { return }

  $idx = [ordered]@{
    schema             = 'session-index/v1'
    schemaVersion      = '1.0.0'
    generatedAtUtc     = (Get-Date).ToUniversalTime().ToString('o')
    resultsDir         = $ResultsDir
    includeIntegration = $false
    integrationMode    = $null
    integrationSource  = $null
    files              = [ordered]@{}
  }
  $sumPath = Join-Path $ResultsDir $SummaryJson
  if (Test-Path -LiteralPath $sumPath -PathType Leaf) {
    try {
      $s = Get-Content -LiteralPath $sumPath -Raw | ConvertFrom-Json -ErrorAction Stop
      $includeIntegration = $false
      if ($s.PSObject.Properties.Name -contains 'includeIntegration') {
        $includeIntegration = [bool]$s.includeIntegration
      }
      $integrationMode = $null
      if ($s.PSObject.Properties.Name -contains 'integrationMode') {
        $integrationMode = $s.integrationMode
      }
      $integrationSource = $null
      if ($s.PSObject.Properties.Name -contains 'integrationSource') {
        $integrationSource = $s.integrationSource
      }
      $idx.includeIntegration = $includeIntegration
      $idx.integrationMode = $integrationMode
      $idx.integrationSource = $integrationSource
      $idx['summary'] = [ordered]@{
        total      = $s.total
        passed     = $s.passed
        failed     = $s.failed
        errors     = $s.errors
        skipped    = $s.skipped
        duration_s = $s.duration_s
        schemaVersion = $s.schemaVersion
      }
      $idx.status = if (($s.failed -gt 0) -or ($s.errors -gt 0)) { 'fail' } else { 'ok' }
      $idx.files['pesterSummaryJson'] = (Split-Path -Leaf $SummaryJson)
      # Minimal step summary
      $lines = @()
      $lines += '### Session Overview (fallback)'
      $lines += ("- Status: {0}" -f $idx.status)
      $lines += ("- Total: {0} | Passed: {1} | Failed: {2} | Errors: {3} | Skipped: {4}" -f $s.total,$s.passed,$s.failed,$s.errors,$s.skipped)
      $lines += ("- Duration (s): {0}" -f $s.duration_s)
      $lines += ("- Include Integration: {0}" -f $includeIntegration)
      if ($integrationMode) { $lines += ("- Integration Mode: {0}" -f $integrationMode) }
      if ($integrationSource) { $lines += ("- Integration Source: {0}" -f $integrationSource) }
      $idx['stepSummary'] = ($lines -join "`n")
    } catch { }
  }
  $idx | ConvertTo-Json -Depth 5 | Out-File -FilePath $idxPath -Encoding utf8
  Write-Host ("Fallback session index created at: {0}" -f $idxPath)
} catch {
  Write-Host "::warning::Ensure-SessionIndex failed: $_"
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