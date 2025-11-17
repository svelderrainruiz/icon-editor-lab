#Requires -Version 7.0
<#
.SYNOPSIS
  Consistent entry point for running the repository's Pester suite.

.DESCRIPTION
  Loads tests/Pester.runsettings.psd1, applies optional tag/exclude filters,
  and runs Invoke-Pester. When -CI is specified, writes JUnit output under
  out/test-results/pester.xml (creating the folder if needed).

.PARAMETER Tag
  Only run tests tagged with any of the specified values.

.PARAMETER ExcludeTag
  Skip tests tagged with any of the specified values.

.PARAMETER CI
  Enables JUnit output to out/test-results/pester.xml.
#>

[CmdletBinding()]
param(
  [string[]]$Tag,
  [string[]]$ExcludeTag,
  [switch]$CI
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$configPath = Join-Path $repoRoot 'tests' 'Pester.runsettings.psd1'
if (-not (Test-Path $configPath)) {
  throw "Pester configuration not found: $configPath"
}

$config = Import-PowerShellDataFile -LiteralPath $configPath

# Normalize relative paths based on repo root
$config.Run.Path = @(
  $config.Run.Path | ForEach-Object {
    (Resolve-Path (Join-Path $repoRoot $_)).ProviderPath
  }
)
$resolvedResultPath = Resolve-Path (Join-Path $repoRoot $config.TestResult.OutputPath) -ErrorAction SilentlyContinue
if ($resolvedResultPath) {
  $config.TestResult.OutputPath = $resolvedResultPath.ProviderPath
} else {
  $config.TestResult.OutputPath = Join-Path $repoRoot 'out/test-results/pester.xml'
}
if (-not $config.TestResult.OutputPath) {
  $config.TestResult.OutputPath = Join-Path $repoRoot 'out/test-results/pester.xml'
}

if ($Tag) {
  $config.Filter.Tag = @($Tag)
}
if ($ExcludeTag) {
  $config.Filter.ExcludeTag = @($ExcludeTag)
}

if ($CI) {
  $resultsPath = $config.TestResult.OutputPath
  $resultsDir = Split-Path $resultsPath -Parent
  if (-not (Test-Path $resultsDir)) { New-Item -ItemType Directory -Path $resultsDir -Force | Out-Null }
  $config.TestResult.Enabled = $true
  Write-Host "CI mode: writing Pester results to $resultsPath"
} else {
  $config.TestResult.Enabled = $false
}

Write-Host "Invoking Pester with tags: $($config.Filter.Tag -join ', ')" -ForegroundColor Cyan
Invoke-Pester -Configuration $config
