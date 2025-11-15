#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = $env:WORKSPACE_ROOT
if (-not $root) {
    $root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..' '..') -ErrorAction Stop).ProviderPath
}

$telemetryDir = Join-Path $root 'tests/results/_agent/icon-editor/dev-mode-run'
if (-not (Test-Path -LiteralPath $telemetryDir -PathType Container)) {
    Write-Warning ("[devmode/deps] Telemetry directory not found at '{0}'." -f $telemetryDir)
    return
}

$files = Get-ChildItem -LiteralPath $telemetryDir -Filter 'dev-mode-run-*.json' -File -ErrorAction SilentlyContinue
if (-not $files) {
    Write-Warning ("[devmode/deps] No dev-mode telemetry runs found under '{0}'." -f $telemetryDir)
    return
}

$records = @()
foreach ($file in $files) {
    try {
        $payload = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ($payload) {
            $records += $payload
        }
    } catch {
        Write-Warning ("[devmode/deps] Failed to parse telemetry run '{0}': {1}" -f $file.FullName, $_.Exception.Message)
    }
}

if (-not $records) {
    Write-Warning ("[devmode/deps] No parseable dev-mode telemetry records found under '{0}'." -f $telemetryDir)
    return
}

# Currently modeled dependency: BuildPackage depends on a prior successful Compare.
$buildRuns = $records | Where-Object {
    $_ -is [psobject] -and $_.PSObject.Properties['operation'] -and
    ([string]$_.operation) -eq 'BuildPackage'
}

if (-not $buildRuns) {
    Write-Warning "[devmode/deps] No BuildPackage runs found; nothing to summarize."
    return
}

$compareRuns = $records | Where-Object {
    $_ -is [psobject] -and $_.PSObject.Properties['operation'] -and
    ([string]$_.operation) -eq 'Compare'
}

function Get-Provider {
    param($Record)
    if (-not $Record -or -not ($Record -is [psobject])) { return '<unknown>' }
    if ($Record.PSObject.Properties['provider'] -and $Record.provider) {
        return [string]$Record.provider
    }
    return '<unknown>'
}

function Get-Status {
    param($Record)
    if (-not $Record -or -not ($Record -is [psobject])) { return '<unknown>' }
    if ($Record.PSObject.Properties['status'] -and $Record.status) {
        return [string]$Record.status
    }
    return '<unknown>'
}

$totalBuild = 0
$succeededWithDep = 0
$succeededWithoutDep = 0
$failedWithDep = 0
$failedWithoutDep = 0

foreach ($build in $buildRuns) {
    $totalBuild++

    $provider = Get-Provider -Record $build
    $status   = Get-Status -Record $build

    $providerCompareRuns = $compareRuns | Where-Object { (Get-Provider -Record $_) -eq $provider }

    $hasAnyCompare = $false
    $hasCompareSuccess = $false

    if ($providerCompareRuns) {
        $hasAnyCompare = $true
        if ($providerCompareRuns | Where-Object { (Get-Status -Record $_) -eq 'succeeded' }) {
            $hasCompareSuccess = $true
        }
    }

    $dependencySatisfied = $hasCompareSuccess

    if ($status -eq 'succeeded') {
        if ($dependencySatisfied) {
            $succeededWithDep++
        } else {
            $succeededWithoutDep++
        }
    } else {
        if ($dependencySatisfied) {
            $failedWithDep++
        } else {
            $failedWithoutDep++
        }
    }
}

$depSummary = [pscustomobject]@{
    Operation                = 'BuildPackage'
    DependsOn                = 'Compare'
    TotalRuns                = $totalBuild
    SucceededWithDependency  = $succeededWithDep
    SucceededWithoutDependency = $succeededWithoutDep
    FailedWithDependency     = $failedWithDep
    FailedWithoutDependency  = $failedWithoutDep
}

$summary = [pscustomobject]@{
    GeneratedAt  = (Get-Date).ToString('o')
    Root         = $root
    TelemetryDir = $telemetryDir
    Dependencies = @($depSummary)
}

if (-not $OutputPath) {
    $OutputPath = Join-Path $root 'tests/results/_agent/icon-editor/dev-mode-dependency-summary.json'
}

$outDir = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}

$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding utf8
Write-Host ("[devmode/deps] Dependency summary written to {0}" -f $OutputPath) -ForegroundColor Cyan

