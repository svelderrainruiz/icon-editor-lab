#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$OutputPath,
    [string]$AnalyzerRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = $env:WORKSPACE_ROOT
if (-not $root) {
    $root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..' '..') -ErrorAction Stop).ProviderPath
}

if ($AnalyzerRoot) {
    $analyzerRoot = (Resolve-Path -LiteralPath $AnalyzerRoot -ErrorAction Stop).ProviderPath
} else {
    $analyzerRoot = Join-Path $root 'tests/results/_agent/vi-analyzer'
}

if (-not (Test-Path -LiteralPath $analyzerRoot -PathType Container)) {
    Write-Warning ("[vianalyzer] Analyzer root not found at '{0}'." -f $analyzerRoot)
    return
}

$mipHelpersPath = Join-Path $root 'src/tools/icon-editor/MipScenarioHelpers.psm1'
if (-not (Test-Path -LiteralPath $mipHelpersPath -PathType Leaf)) {
    Write-Warning ("[vianalyzer] Helper module not found at '{0}'." -f $mipHelpersPath)
    return
}

Import-Module $mipHelpersPath -Force

$files = Get-ChildItem -LiteralPath $analyzerRoot -Recurse -Filter 'vi-analyzer.json' -File -ErrorAction SilentlyContinue
if (-not $files) {
    Write-Warning ("[vianalyzer] No vi-analyzer.json files found under '{0}'." -f $analyzerRoot)
    return
}

$total = 0
$byFamily = @{}
$runs = @()

foreach ($file in $files) {
    try {
        $family = Get-VIAnalyzerScenarioFamily -AnalyzerJsonPath $file.FullName
    } catch {
        Write-Warning ("[vianalyzer] Failed to classify '{0}': {1}" -f $file.FullName, $_.Exception.Message)
        continue
    }

    if (-not $family) { $family = 'vianalyzer.unknown' }

    $total++
    if (-not $byFamily.ContainsKey($family)) {
        $byFamily[$family] = 0
    }
    $byFamily[$family]++

    $runs += [pscustomobject]@{
        Family = $family
        Path   = $file.FullName
    }
}

if ($total -eq 0) {
    Write-Warning ("[vianalyzer] No classifier results produced under '{0}'." -f $analyzerRoot)
    return
}

$familySummaries = @()
foreach ($entry in $byFamily.GetEnumerator() | Sort-Object Name) {
    $familySummaries += [pscustomobject]@{
        Family = $entry.Key
        Count  = $entry.Value
    }
}

if (-not $OutputPath) {
    $OutputPath = Join-Path $root 'tests/results/_agent/vi-analyzer/vi-analyzer-family-summary.json'
}

$outDir = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outDir -PathType Container)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$summary = [pscustomobject]@{
    GeneratedAt  = (Get-Date).ToString('o')
    Root         = $root
    AnalyzerRoot = $analyzerRoot
    TotalRuns    = $total
    ByFamily     = $familySummaries
    Runs         = $runs
}

$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding utf8
Write-Host ("[vianalyzer] Family summary written to {0}" -f $OutputPath) -ForegroundColor Cyan

