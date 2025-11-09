#Requires -Version 7.0
[CmdletBinding()]
param(
  [string]$LabVIEWPath = 'C:\Program Files\National Instruments\LabVIEW 2025\LabVIEW.exe',
  [string]$BaseVI = 'vendor\icon-editor\.github\actions\missing-in-project\MissingInProject.vi',
  [string]$HeadVI = 'vendor\icon-editor\.github\actions\missing-in-project\MissingInProjectCLI.vi',
  [string]$OutputRoot = 'tests/results/teststand-session',
  [string]$Label = 'vi-compare-smoke',
  [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function Resolve-VIPath {
  param([string]$PathValue)
  if ([string]::IsNullOrWhiteSpace($PathValue)) {
    throw "VI path was not provided."
  }
  if ([System.IO.Path]::IsPathRooted($PathValue)) {
    return (Resolve-Path -LiteralPath $PathValue -ErrorAction Stop).Path
  }
  $candidate = Join-Path $repoRoot $PathValue
  return (Resolve-Path -LiteralPath $candidate -ErrorAction Stop).Path
}

$basePath = Resolve-VIPath -PathValue $BaseVI
$headPath = Resolve-VIPath -PathValue $HeadVI

if (-not (Test-Path -LiteralPath $LabVIEWPath -PathType Leaf)) {
  throw "LabVIEW executable not found at '$LabVIEWPath'. Supply -LabVIEWPath pointing at a valid install."
}

$harness = Join-Path $repoRoot 'tools\TestStand-CompareHarness.ps1'
if (-not (Test-Path -LiteralPath $harness -PathType Leaf)) {
  throw "Compare harness not found at '$harness'."
}

if (-not (Test-Path -LiteralPath $OutputRoot -PathType Container)) {
  New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
}
$outputDir = Join-Path $OutputRoot $Label
if (-not (Test-Path -LiteralPath $outputDir -PathType Container)) {
  New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$args = @(
  '-BaseVi', $basePath,
  '-HeadVi', $headPath,
  '-LabVIEWPath', $LabVIEWPath,
  '-OutputRoot', $outputDir,
  '-Warmup', 'skip',
  '-RenderReport',
  '-CloseLabVIEW',
  '-CloseLVCompare',
  '-SameNameHint'
)

if ($DryRun) {
  Write-Host "Dry run: pwsh -File $harness $($args -join ' ')"
  return
}

Write-Host "Running VI comparison smoke in $repoRoot"
& pwsh -NoLogo -NoProfile -File $harness @args
$exit = $LASTEXITCODE
if ($exit -ne 0) {
  throw "Compare harness exited with $exit."
}

$report = Get-ChildItem -LiteralPath $outputDir -Recurse -Filter 'compare-report.html' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($report) {
  Write-Host ("Report written to {0}" -f $report.FullName)
} else {
  Write-Warning "Compare harness completed but no compare-report.html was found under $outputDir."
}
