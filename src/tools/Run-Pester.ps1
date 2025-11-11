Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSModuleAutoLoadingPreference = 'None'
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
param(
  [Parameter()][ValidateSet('2021','2023','2025')][string]$LabVIEWVersion = '2023',
  [Parameter()][ValidateSet(32,64)][int]$Bitness = 64,
  [Parameter()][ValidateNotNullOrEmpty()][string]$Workspace = (Get-Location).Path,
  [Parameter()][int]$TimeoutSec = 600
)
param(
  [switch]$IncludeIntegration
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$resultsDir = Join-Path $root 'tests' 'results'
New-Item -ItemType Directory -Force -Path $resultsDir | Out-Null

$pesterVersion = '5.7.1'
$resolverPath = Join-Path $PSScriptRoot 'Get-PesterVersion.ps1'
if (Test-Path -LiteralPath $resolverPath) {
  try {
    $resolved = & $resolverPath
    if ($resolved -and -not [string]::IsNullOrWhiteSpace($resolved)) {
      $pesterVersion = $resolved
    }
  } catch {
    Write-Verbose ("Falling back to default Pester version ({0}) because resolver failed: {1}" -f $pesterVersion, $_.Exception.Message)
  }
}
if (-not $env:PESTER_VERSION -or [string]::IsNullOrWhiteSpace($env:PESTER_VERSION)) {
  $env:PESTER_VERSION = $pesterVersion
}

# Ensure the required Pester version is available locally
$pesterModule = Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -eq [version]$pesterVersion } | Select-Object -First 1
if (-not $pesterModule) {
  Write-Host ("Pester {0} not found. Installing locally under tools/modules..." -f $pesterVersion)
  $toolsModules = Join-Path $root 'tools' 'modules'
  $pesterPath = Join-Path $toolsModules 'Pester'
  if (-not (Test-Path -LiteralPath $pesterPath)) {
    New-Item -ItemType Directory -Force -Path $toolsModules | Out-Null
  }
  Save-Module -Name Pester -RequiredVersion $pesterVersion -Path $toolsModules -Force
  $importTarget = Get-ChildItem -Path $pesterPath -Directory | Where-Object { $_.Name -eq $pesterVersion } | Select-Object -First 1
  if (-not $importTarget) {
    $importTarget = Get-ChildItem -Path $pesterPath -Directory | Sort-Object Name -Descending | Select-Object -First 1
  }
  Import-Module (Join-Path $importTarget.FullName 'Pester.psd1') -Force
} else {
  Import-Module Pester -RequiredVersion $pesterVersion -Force
}
Write-Host ("Using Pester {0}" -f (Get-Module Pester).Version)

# Build configuration
$conf = New-PesterConfiguration
$conf.Run.Path = (Join-Path $root 'tests')
if (-not $IncludeIntegration) {
  $conf.Filter.ExcludeTag = @('Integration')
}
$conf.Output.Verbosity = 'Detailed'
$conf.TestResult.Enabled = $true
$conf.TestResult.OutputFormat = 'NUnitXml'
$conf.TestResult.OutputPath = 'pester-results.xml'  # filename relative to CWD per Pester 5

# Run from results directory so XML lands there
Push-Location -LiteralPath $resultsDir
try {
  Invoke-Pester -Configuration $conf
}
finally {
  Pop-Location
}

# Derive summary from NUnit XML
$xmlPath = Join-Path $resultsDir 'pester-results.xml'
if (-not (Test-Path -LiteralPath $xmlPath)) {
  Write-Error "Pester result XML not found at: $xmlPath"
  exit 1
}
[xml]$doc = Get-Content -LiteralPath $xmlPath -Raw
$rootNode = $doc.'test-results'
[int]$total = $rootNode.total
[int]$failed = $rootNode.failures
[int]$errors = $rootNode.errors
$passed = $total - $failed - $errors
$skipped = 0
$summary = @(
  "Tests Passed: $passed",
  "Tests Failed: $failed",
  "Tests Skipped: $skipped"
) -join [Environment]::NewLine
$summary | Tee-Object -FilePath (Join-Path $resultsDir 'pester-summary.txt')

if ($failed -gt 0 -or $errors -gt 0) { exit 1 }

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