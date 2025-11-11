
#Requires -Version 7.2
param(
  [string]$TagFilter = 'tools',
  [string]$ResultsPath = 'artifacts',
  [switch]$InstallPester
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($InstallPester) {
  if (-not (Get-Module -ListAvailable -Name Pester)) {
    Write-Host "Installing Pester (CurrentUser scope)..." -ForegroundColor Cyan
    Install-Module Pester -MinimumVersion 5.4.0 -Force -SkipPublisherCheck -Scope CurrentUser
  }
}

$null = New-Item -ItemType Directory -Force -Path $ResultsPath

$cfg = New-PesterConfiguration
$cfg.Run.Path = @('tests/tools')
$cfg.Run.PassThru = $true
$cfg.Run.Exit = $false
$cfg.Output.Verbosity = 'Detailed'
$cfg.TestResult.Enabled = $true
$cfg.TestResult.OutputPath = Join-Path $ResultsPath 'TestResults.xml'
$cfg.TestResult.OutputFormat = 'NUnitXml'

# Code coverage over .ps1 tools (aggregate)
$cfg.CodeCoverage.Enabled = $true
$cfg.CodeCoverage.Path = @('tools/*.ps1')
$cfg.CodeCoverage.OutputPath = Join-Path $ResultsPath 'CodeCoverage.xml'

$result = Invoke-Pester -Configuration $cfg

Write-Host ("Tests: {0} passed, {1} failed" -f $result.PassedCount, $result.FailedCount)
if ($result.FailedCount -gt 0) {
  Write-Error "Pester failures detected in tools/ tests."
  exit 1
}

# Optional: fail build if coverage data is missing (we don't set a numeric threshold here)
if (-not (Test-Path -LiteralPath (Join-Path $ResultsPath 'CodeCoverage.xml'))) {
  Write-Error "CodeCoverage.xml not produced."
  exit 1
}
