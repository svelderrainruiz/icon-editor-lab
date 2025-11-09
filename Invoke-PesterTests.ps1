#Requires -Version 7.0

<#
.SYNOPSIS
  Minimal Pester dispatcher used by local agents and Scenario 6 orchestration.

.DESCRIPTION
  Restores the original behaviour expected by helpers such as
  Invoke-MissingInProjectSuite.ps1. Accepts the common parameters surfaced in the
  repo (TestsPath, IntegrationMode, ResultsPath) and writes a lightweight
  summary/JUnit report under the requested results directory.
#>
[CmdletBinding()]
param(
  [string]$TestsPath = 'tests',
  [ValidateSet('auto','include','exclude')]
  [string]$IntegrationMode = 'auto',
  [string]$ResultsPath = 'tests/results',
  [string]$JsonSummaryPath = 'pester-summary.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable -Name Pester)) {
  throw 'Pester module not available. Please install/import Pester v5+ on this runner.'
}
Get-Module Pester -ErrorAction SilentlyContinue | ForEach-Object { Remove-Module $_ -Force }
Import-Module Pester -MinimumVersion 5.5 -Force

$testsResolved = Resolve-Path -LiteralPath $TestsPath -ErrorAction Stop
$resultsResolved = if ([System.IO.Path]::IsPathRooted($ResultsPath)) {
  $ResultsPath
} else {
  Join-Path (Resolve-Path .).Path $ResultsPath
}
if (-not (Test-Path -LiteralPath $resultsResolved -PathType Container)) {
  [void](New-Item -ItemType Directory -Path $resultsResolved -Force)
}

$jsonSummaryPathResolved = Join-Path $resultsResolved $JsonSummaryPath
$textSummaryPath = Join-Path $resultsResolved 'pester-summary.txt'

$config = New-PesterConfiguration
$config.Run.Path = $testsResolved.ProviderPath
$config.Run.PassThru = $true
$config.Run.Exit = $false
$config.Output.Verbosity = 'Detailed'
$config.TestResult.Enabled = $true
$config.TestResult.OutputFormat = 'NUnitXml'
$config.TestResult.OutputPath = $jsonSummaryPathResolved

switch ($IntegrationMode) {
  'exclude' { $config.Filter.ExcludeTag = @('Integration') }
  'include' { }
  default   { } # auto == include for this minimal dispatcher
}

Write-Host ("Running Pester suite from {0}" -f $testsResolved.ProviderPath) -ForegroundColor Cyan
$result = Invoke-Pester -Configuration $config

$summaryLine = "Total: {0}  Passed: {1}  Failed: {2}  Skipped: {3}" -f `
  $result.TotalCount, $result.PassedCount, $result.FailedCount, $result.SkippedCount
Set-Content -LiteralPath $textSummaryPath -Value $summaryLine -Encoding UTF8
Write-Host $summaryLine

$failedTestsCount = 0
if ($result.PSObject.Properties.Match('FailedTests').Count -gt 0 -and $result.FailedTests) {
  $failedTestsCount = $result.FailedTests.Count
}
if ($result.FailedCount -gt 0 -or $failedTestsCount -gt 0) {
  exit 1
}
exit 0
