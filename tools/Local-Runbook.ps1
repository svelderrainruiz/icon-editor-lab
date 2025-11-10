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
  [switch]$All,
  [string[]]$Phases,
  [string]$Profile = 'quick',
  [switch]$IncludeLoop,
  [switch]$FailOnDiff,
  [string]$JsonReport,
  [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $PSCommandPath
$repoRoot = Resolve-Path (Join-Path $scriptRoot '..') | Select-Object -ExpandProperty Path

Push-Location $repoRoot
try {
  Write-Host "=== Local Runbook ===" -ForegroundColor Cyan
  Write-Host ("Repository: {0}" -f $repoRoot) -ForegroundColor Gray

  # Default phases for local sanity runs
  $profiles = @{
    quick   = @('Prereqs','ViInputs','Compare')
    compare = @('Prereqs','Compare')
    loop    = @('Prereqs','ViInputs','Compare','Loop')
    full    = @()
  }

  $selectedPhases = @()
  if ($All) {
    $selectedPhases = @()
  } elseif ($Phases -and $Phases.Count -gt 0) {
    $selectedPhases = $Phases
  } else {
    $profileKey = ($Profile ?? 'quick').ToLowerInvariant()
    if ($profiles.ContainsKey($profileKey)) {
      $selectedPhases = $profiles[$profileKey]
    } else {
      Write-Warning "Unknown profile '$Profile'; defaulting to quick"
      $selectedPhases = $profiles.quick
    }
    if ($IncludeLoop -and $selectedPhases) {
      if ($selectedPhases -notcontains 'Loop') { $selectedPhases += 'Loop' }
    } elseif ($IncludeLoop -and -not $selectedPhases) {
      $selectedPhases = @('Loop')
    }
  }

  $env:RUNBOOK_LOOP_ITERATIONS = '1'
  $env:RUNBOOK_LOOP_QUICK = '1'
  if ($FailOnDiff) { $env:RUNBOOK_LOOP_FAIL_ON_DIFF = '1' } else { Remove-Item Env:RUNBOOK_LOOP_FAIL_ON_DIFF -ErrorAction SilentlyContinue }

  $runbookArgs = @()
  if ($All) { $runbookArgs += '-All' }
  if ($selectedPhases.Count -gt 0 -and -not $All) {
    $runbookArgs += @('-Phases', ($selectedPhases -join ',')) 
  }
  if ($FailOnDiff) { $runbookArgs += '-FailOnDiff' }
  if ($JsonReport) { $runbookArgs += @('-JsonReport', $JsonReport) }
  if ($PassThru) { $runbookArgs += '-PassThru' }

  Write-Host "Invoking Invoke-IntegrationRunbook.ps1 with arguments:" -ForegroundColor Gray
  if ($runbookArgs.Count -eq 0) { Write-Host '  (none)' -ForegroundColor DarkGray }
  else {
    $runbookArgs | ForEach-Object { Write-Host ("  {0}" -f $_) -ForegroundColor DarkGray }
  }

  & "$repoRoot/scripts/Invoke-IntegrationRunbook.ps1" @runbookArgs
  exit $LASTEXITCODE
}
finally {
  Pop-Location
  Remove-Item Env:RUNBOOK_LOOP_ITERATIONS -ErrorAction SilentlyContinue
  Remove-Item Env:RUNBOOK_LOOP_QUICK -ErrorAction SilentlyContinue
  Remove-Item Env:RUNBOOK_LOOP_FAIL_ON_DIFF -ErrorAction SilentlyContinue
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