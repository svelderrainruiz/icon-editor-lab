#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$SummaryRoot,
    [string]$RunSummaryPath
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
    Write-Warning ("[vihistory/anomaly] Summary root not found at '{0}'." -f $summaryRoot)
    return
}

if (-not $RunSummaryPath) {
    $RunSummaryPath = Join-Path $root 'tests/results/_agent/vi-history/vi-history-run-summary.json'
}

if (-not (Test-Path -LiteralPath $RunSummaryPath -PathType Leaf)) {
    $runSummaryScript = Join-Path $PSScriptRoot 'Summarize-VIHistoryRuns.ps1'
    if (-not (Test-Path -LiteralPath $runSummaryScript -PathType Leaf)) {
        Write-Warning "[vihistory/anomaly] Summarize-VIHistoryRuns.ps1 not found; cannot build run summary."
        return
    }

    & $runSummaryScript -SummaryRoot $summaryRoot -OutputPath $RunSummaryPath -ErrorAction Stop
}

if (-not (Test-Path -LiteralPath $RunSummaryPath -PathType Leaf)) {
    Write-Warning ("[vihistory/anomaly] Run summary JSON not found at '{0}'." -f $RunSummaryPath)
    return
}

$raw = Get-Content -LiteralPath $RunSummaryPath -Raw -ErrorAction Stop
if ([string]::IsNullOrWhiteSpace($raw)) {
    Write-Warning ("[vihistory/anomaly] Run summary at '{0}' is empty." -f $RunSummaryPath)
    return
}

$summary = $raw | ConvertFrom-Json -ErrorAction Stop
if (-not $summary -or -not $summary.PSObject.Properties['Runs']) {
    Write-Warning ("[vihistory/anomaly] Run summary at '{0}' has no Runs collection." -f $RunSummaryPath)
    return
}

$runs = @($summary.Runs)
if (-not $runs -or $runs.Count -eq 0) {
    Write-Warning ("[vihistory/anomaly] Run summary at '{0}' has no runs." -f $RunSummaryPath)
    return
}

$best = $null
$bestScore = [double]::NegativeInfinity

foreach ($run in $runs) {
    if (-not $run) { continue }

    $completedDiff = 0
    $errorCount    = 0
    $skipped       = 0

    if ($run.PSObject.Properties['CompletedDiff']) {
        $completedDiff = [int]$run.CompletedDiff
    }
    if ($run.PSObject.Properties['Error']) {
        $errorCount = [int]$run.Error
    }
    if ($run.PSObject.Properties['Skipped']) {
        $skipped = [int]$run.Skipped
    }

    # Weight errors highest, then completed diffs, then skipped entries.
    $score = ($errorCount * 1000) + ($completedDiff * 10) + $skipped

    if ($score -gt $bestScore) {
        $bestScore = $score
        $best = $run
    }
}

if (-not $best) {
    Write-Warning "[vihistory/anomaly] No candidate run found in summary."
    return
}

$hint = @()
if ($best.Error -gt 0) {
    $hint += "Run has VI History targets with status='error'; inspect this summary first."
} elseif ($best.CompletedDiff -gt 0) {
    $hint += "Run has VI History targets with non-zero diffs; check whether these diffs are expected or noisy."
} elseif ($best.Skipped -gt 0) {
    $hint += "Run has skipped VI History targets; verify inclusion/exclusion rules and inputs."
}

[pscustomobject]@{
    Kind            = 'vihistory-anomaly-candidate'
    WorkspaceRoot   = $root
    RunSummaryPath  = (Resolve-Path -LiteralPath $RunSummaryPath).ProviderPath
    FilePath        = $best.FilePath
    Targets         = $best.Targets
    CompletedMatch  = $best.CompletedMatch
    CompletedDiff   = $best.CompletedDiff
    Error           = $best.Error
    Skipped         = $best.Skipped
    Other           = $best.Other
    Score           = $bestScore
    Hint            = ($hint -join ' ')
}

