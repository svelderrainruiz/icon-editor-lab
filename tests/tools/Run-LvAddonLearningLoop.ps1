#Requires -Version 7.0
[CmdletBinding()]
param(
    [int]$MaxRecords = 10
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = $env:WORKSPACE_ROOT
if (-not $root) {
    $root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..' '..') -ErrorAction Stop).ProviderPath
}

Write-Host "[lvaddon/learn] WorkspaceRoot: $root" -ForegroundColor DarkGray

$summaryScript = Join-Path $PSScriptRoot 'Summarize-LabviewDevmodeLogs.ps1'
if (-not (Test-Path -LiteralPath $summaryScript -PathType Leaf)) {
    Write-Warning "[lvaddon/learn] Summarize-LabviewDevmodeLogs.ps1 not found; skipping summary generation."
} else {
    & $summaryScript -ErrorAction Stop
}

$viHistorySummaryScript = Join-Path $PSScriptRoot 'Summarize-VIHistoryRuns.ps1'
if (-not (Test-Path -LiteralPath $viHistorySummaryScript -PathType Leaf)) {
    Write-Warning "[lvaddon/learn] Summarize-VIHistoryRuns.ps1 not found; skipping VI history run summary."
} else {
    & $viHistorySummaryScript -ErrorAction Stop
}

$viHistoryFamiliesScript = Join-Path $PSScriptRoot 'Summarize-VIHistoryFamilies.ps1'
if (-not (Test-Path -LiteralPath $viHistoryFamiliesScript -PathType Leaf)) {
    Write-Warning "[lvaddon/learn] Summarize-VIHistoryFamilies.ps1 not found; skipping VI history family summary."
} else {
    & $viHistoryFamiliesScript -ErrorAction Stop
}

$vipmSummaryScript = Join-Path $PSScriptRoot 'Summarize-VipmInstallLogs.ps1'
if (-not (Test-Path -LiteralPath $vipmSummaryScript -PathType Leaf)) {
    Write-Warning "[lvaddon/learn] Summarize-VipmInstallLogs.ps1 not found; skipping VIPM install summary."
} else {
    & $vipmSummaryScript -ErrorAction Stop
}

$viHistoryAnomalyScript = Join-Path $PSScriptRoot 'Find-VIHistoryAnomalies.ps1'
if (-not (Test-Path -LiteralPath $viHistoryAnomalyScript -PathType Leaf)) {
    Write-Warning "[lvaddon/learn] Find-VIHistoryAnomalies.ps1 not found; skipping VI history anomaly scan."
} else {
    try {
        $candidate = & $viHistoryAnomalyScript -ErrorAction Stop
        if ($candidate) {
            Write-Host "[lvaddon/learn] VI History anomaly candidate:" -ForegroundColor DarkYellow
            Write-Host ("  FilePath:       {0}" -f $candidate.FilePath) -ForegroundColor DarkYellow
            Write-Host ("  Targets:        {0}" -f $candidate.Targets) -ForegroundColor DarkYellow
            Write-Host ("  CompletedDiff:  {0}" -f $candidate.CompletedDiff) -ForegroundColor DarkYellow
            Write-Host ("  Error:          {0}" -f $candidate.Error) -ForegroundColor DarkYellow
            if ($candidate.Hint) {
                Write-Host ("  Hint:           {0}" -f $candidate.Hint) -ForegroundColor DarkYellow
            }
        } else {
            Write-Host "[lvaddon/learn] VI History anomaly scan: no runs found to analyse." -ForegroundColor DarkGray
        }
    } catch {
        Write-Warning ("[lvaddon/learn] VI History anomaly scan failed: {0}" -f $_.Exception.Message)
    }
}

$snippetScript = Join-Path $PSScriptRoot 'New-LvAddonLearningSnippet.ps1'
if (-not (Test-Path -LiteralPath $snippetScript -PathType Leaf)) {
    Write-Warning "[lvaddon/learn] New-LvAddonLearningSnippet.ps1 not found; cannot generate learning snippet."
    return
}

& $snippetScript -MaxRecords $MaxRecords -ErrorAction Stop

$defaultSnippetPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-learning-snippet.json'
if (Test-Path -LiteralPath $defaultSnippetPath -PathType Leaf) {
    Write-Host "[lvaddon/learn] Learning snippet ready at:" -ForegroundColor Cyan
    Write-Host "  $defaultSnippetPath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Next step (for a future agent): open this JSON, read 'AgentInstructions' and 'SampleRecords', and refine LvAddon dev-mode x-cli scenarios and stderr behaviors based on observed patterns." -ForegroundColor DarkGray
} else {
    Write-Warning "[lvaddon/learn] Learning snippet was not found at the default path; check script output for errors."
}
