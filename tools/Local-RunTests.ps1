<#
.SYNOPSIS
  TODO: Brief synopsis for this tool function/script. (Auto-generated placeholder)
.DESCRIPTION
  TODO: Expand description. Replace this header with real help content.
#>

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
  [string[]]$IncludePatterns,
  [switch]$IncludeIntegration,
  [string]$Profile = 'quick',
  [string]$TestsPath = 'tests',
  [string]$ResultsPath = 'tests/results',
  [switch]$EmitFailuresJsonAlways
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $PSCommandPath
$repoRoot = Resolve-Path (Join-Path $scriptRoot '..') | Select-Object -ExpandProperty Path

Push-Location $repoRoot
try {
  Write-Host "=== Local Run Tests ===" -ForegroundColor Cyan
  Write-Host ("Repository: {0}" -f $repoRoot) -ForegroundColor Gray

  # Ensure local-friendly environment (no session locks or GH-only toggles)
  foreach ($name in @(
      'SESSION_LOCK_ENABLED',
      'SESSION_LOCK_FORCE',
      'SESSION_LOCK_STRICT',
      'CLAIM_PESTER_LOCK',
      'STUCK_GUARD',
      'WIRE_PROBES',
      'SEND_CTRL_C'
    )) {
    Remove-Item "Env:$name" -ErrorAction SilentlyContinue
  }
  $env:SESSION_LOCK_STRICT = '0'
  $env:STUCK_GUARD = '0'
  $env:LOCAL_DISPATCHER = '1'

  $profiles = @{
    quick    = @(
      'RunnerInvoker.*',
      'CompareVI.ArgumentPreview.Tests.ps1',
      'OnFixtureValidationFail.DiffDetails.Tests.ps1',
      'Invoker.Basic.Tests.ps1'
    )
    invoker  = @('RunnerInvoker.*','Invoker.Basic.Tests.ps1')
    compare  = @('CompareVI.*.ps1')
    fixtures = @('OnFixtureValidationFail.*.ps1')
    loop     = @('CompareLoop.*.ps1','Integration-ControlLoop*.ps1','LoopMetrics.Tests.ps1')
    full     = @() # no filters
  }

  $integrationMode = if ($IncludeIntegration.IsPresent) { 'include' } else { 'exclude' }
  $invokeParams = @{
    TestsPath       = $TestsPath
    ResultsPath     = $ResultsPath
    IntegrationMode = $integrationMode
  }
  $effectivePatterns = @()
  if ($IncludePatterns -and $IncludePatterns.Count -gt 0) {
    $effectivePatterns = $IncludePatterns
  } else {
    $profileKey = ($Profile ?? 'quick').ToLowerInvariant()
    if ($profiles.ContainsKey($profileKey)) {
      $effectivePatterns = $profiles[$profileKey]
    } else {
      Write-Warning "Unknown profile '$Profile'; running full suite."
      $effectivePatterns = @()
    }
  }
  if ($effectivePatterns -and $effectivePatterns.Count -gt 0) {
    $invokeParams.IncludePatterns = $effectivePatterns
  }

  if ($EmitFailuresJsonAlways) {
    $invokeParams.EmitFailuresJsonAlways = $true
  }

  Write-Host "Dispatching Invoke-PesterTests.ps1 with parameters:" -ForegroundColor Gray
  $invokeParams.GetEnumerator() | Sort-Object Name | ForEach-Object {
    Write-Host ("  {0} = {1}" -f $_.Key, ($_.Value -join ', ')) -ForegroundColor DarkGray
  }

  . "$repoRoot/Invoke-PesterTests.ps1" @invokeParams
  exit $LASTEXITCODE
}
finally {
  Remove-Item Env:LOCAL_DISPATCHER -ErrorAction SilentlyContinue
  Pop-Location
}

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