#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$OutputPath,
    [string]$SummaryRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-VIHistoryFamily {
    param(
        [Parameter(Mandatory)][psobject]$Summary
    )

    if (-not $Summary.PSObject.Properties['totals']) {
        return 'vihistory.unknown'
    }

    $totals = $Summary.totals
    if (-not $totals) {
        return 'vihistory.unknown'
    }

    $targets      = 0
    $diffTargets  = 0
    $errors       = 0
    $skipped      = 0

    if ($totals.PSObject.Properties['targets']) {
        $targets = [int]$totals.targets
    }
    if ($totals.PSObject.Properties['diffTargets']) {
        $diffTargets = [int]$totals.diffTargets
    }
    if ($totals.PSObject.Properties['errors']) {
        $errors = [int]$totals.errors
    }
    if ($totals.PSObject.Properties['skippedEntries']) {
        $skipped = [int]$totals.skippedEntries
    }

    if ($errors -gt 0) {
        return 'vihistory.error'
    }

    if ($diffTargets -gt 0) {
        return 'vihistory.diff'
    }

    if ($skipped -gt 0) {
        return 'vihistory.skipped'
    }

    if ($targets -eq 0) {
        return 'vihistory.empty'
    }

    return 'vihistory.ok'
}

$root = $env:WORKSPACE_ROOT
if (-not $root) {
    $root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..' '..') -ErrorAction Stop).ProviderPath
}

if ($SummaryRoot) {
    $summaryRoot = (Resolve-Path -LiteralPath $SummaryRoot -ErrorAction Stop).ProviderPath
} else {
    $summaryRoot = Join-Path $root 'tests/results/pr-vi-history'
}

if (-not (Test-Path -LiteralPath $summaryRoot -PathType Container)) {
    Write-Warning ("[vihistory] Summary root not found at '{0}'." -f $summaryRoot)
    return
}

$files = Get-ChildItem -LiteralPath $summaryRoot -Recurse -Filter 'vi-history-summary.json' -File -ErrorAction SilentlyContinue
if (-not $files) {
    Write-Warning ("[vihistory] No vi-history-summary.json files found under '{0}'." -f $summaryRoot)
    return
}

$totalRuns = 0
$byFamily = @{}
$runs = @()

foreach ($file in $files) {
    $raw = $null
    try {
        $raw = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop
        if (-not $raw) { continue }
    } catch {
        Write-Warning ("[vihistory] Failed to read summary '{0}': {1}" -f $file.FullName, $_.Exception.Message)
        continue
    }

    $summary = $null
    try {
        $summary = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Warning ("[vihistory] Summary '{0}' is not valid JSON: {1}" -f $file.FullName, $_.Exception.Message)
        continue
    }

    if (-not $summary) { continue }
    if (-not $summary.PSObject.Properties['schema'] -or $summary.schema -ne 'pr-vi-history-summary@v1') {
        continue
    }

    $family = Get-VIHistoryFamily -Summary $summary
    if (-not $family) { $family = 'vihistory.unknown' }

    $totalRuns++
    if (-not $byFamily.ContainsKey($family)) {
        $byFamily[$family] = 0
    }
    $byFamily[$family]++

    $targets     = 0
    $diffTargets = 0
    $errors      = 0
    $skipped     = 0

    if ($summary.totals) {
        if ($summary.totals.PSObject.Properties['targets']) {
            $targets = [int]$summary.totals.targets
        }
        if ($summary.totals.PSObject.Properties['diffTargets']) {
            $diffTargets = [int]$summary.totals.diffTargets
        }
        if ($summary.totals.PSObject.Properties['errors']) {
            $errors = [int]$summary.totals.errors
        }
        if ($summary.totals.PSObject.Properties['skippedEntries']) {
            $skipped = [int]$summary.totals.skippedEntries
        }
    }

    $runs += [pscustomobject]@{
        Family       = $family
        Path         = $file.FullName
        Targets      = $targets
        DiffTargets  = $diffTargets
        Errors       = $errors
        SkippedEntries = $skipped
    }
}

if ($totalRuns -eq 0) {
    Write-Warning ("[vihistory] No valid pr-vi-history-summary@v1 files found under '{0}'." -f $summaryRoot)
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
    $OutputPath = Join-Path $root 'tests/results/_agent/vi-history/vi-history-family-summary.json'
}

$outDir = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outDir -PathType Container)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$summaryOut = [pscustomobject]@{
    GeneratedAt = (Get-Date).ToString('o')
    Root        = $root
    SummaryRoot = $summaryRoot
    TotalRuns   = $totalRuns
    ByFamily    = $familySummaries
    Runs        = $runs
}

$summaryOut | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding utf8
Write-Host ("[vihistory] Family summary written to {0}" -f $OutputPath) -ForegroundColor Cyan

