#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$OutputPath,
    [string]$SummaryRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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

$perRun = @()
$totalTargets = 0
$aggCompletedMatch = 0
$aggCompletedDiff  = 0
$aggError          = 0
$aggSkipped        = 0
$aggOther          = 0

foreach ($file in $files) {
    $raw = $null
    try {
        $raw = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop
    } catch {
        Write-Warning ("[vihistory] Failed to read summary '{0}': {1}" -f $file.FullName, $_.Exception.Message)
        continue
    }

    if ([string]::IsNullOrWhiteSpace($raw)) {
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

    $targets = @()
    if ($summary.targets -is [System.Collections.IEnumerable]) {
        $targets = @($summary.targets)
    }

    $runTargets = $targets.Count
    $totalTargets += $runTargets

    $completedMatch = 0
    $completedDiff  = 0
    $errorCount     = 0
    $skippedCount   = 0
    $otherCount     = 0

    foreach ($target in $targets) {
        if (-not $target) { continue }

        $status = if ($target.PSObject.Properties['status']) { [string]$target.status } else { 'unknown' }

        $diffs = 0
        if ($target.PSObject.Properties['stats'] -and $target.stats) {
            $stats = $target.stats
            if ($stats.PSObject.Properties['diffs']) {
                $diffs = [int]$stats.diffs
            }
        }

        switch ($status) {
            'completed' {
                if ($diffs -gt 0) {
                    $completedDiff++
                    $aggCompletedDiff++
                } else {
                    $completedMatch++
                    $aggCompletedMatch++
                }
            }
            'error' {
                $errorCount++
                $aggError++
            }
            'skipped' {
                $skippedCount++
                $aggSkipped++
            }
            default {
                $otherCount++
                $aggOther++
            }
        }
    }

    $perRun += [pscustomobject]@{
        FilePath       = $file.FullName
        Targets        = $runTargets
        CompletedMatch = $completedMatch
        CompletedDiff  = $completedDiff
        Error          = $errorCount
        Skipped        = $skippedCount
        Other          = $otherCount
    }
}

if (-not $perRun) {
    Write-Warning ("[vihistory] No valid pr-vi-history-summary@v1 files found under '{0}'." -f $summaryRoot)
    return
}

if (-not $OutputPath) {
    $OutputPath = Join-Path $root 'tests/results/_agent/vi-history/vi-history-run-summary.json'
}

$outDir = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}

$summaryOut = [pscustomobject]@{
    GeneratedAt = (Get-Date).ToString('o')
    Root        = $root
    SummaryRoot = $summaryRoot
    TotalSummaries = $perRun.Count
    TotalTargets   = $totalTargets
    Totals = [pscustomobject]@{
        CompletedMatch = $aggCompletedMatch
        CompletedDiff  = $aggCompletedDiff
        Error          = $aggError
        Skipped        = $aggSkipped
        Other          = $aggOther
    }
    Runs = $perRun
}

$summaryOut | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $OutputPath -Encoding utf8
Write-Host ("[vihistory] Run summary written to {0}" -f $OutputPath) -ForegroundColor Cyan

