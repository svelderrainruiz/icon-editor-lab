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
    Write-Warning ("[devmode/stage-graph] Telemetry directory not found at '{0}'." -f $telemetryDir)
    return
}

$files = Get-ChildItem -LiteralPath $telemetryDir -Filter 'dev-mode-run-*.json' -File -ErrorAction SilentlyContinue
if (-not $files) {
    Write-Warning ("[devmode/stage-graph] No dev-mode telemetry runs found under '{0}'." -f $telemetryDir)
    return
}

function Get-StageKind {
    param([string]$Name)

    if (-not $Name) { return '<none>' }

    if ($Name -eq 'rogue-check') { return 'rogue-check' }
    if ($Name -like 'enable-addtoken-*') { return 'enable-addtoken' }
    if ($Name -like 'enable-prepare-*') { return 'enable-prepare' }
    if ($Name -like 'disable-close-*') { return 'disable-close' }
    if ($Name -eq 'enable-dev-mode') { return 'enable-dev-mode' }
    return '<other>'
}

$runs = @()

foreach ($file in $files) {
    $payload = $null
    try {
        $payload = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Warning ("[devmode/stage-graph] Failed to parse telemetry run '{0}': {1}" -f $file.FullName, $_.Exception.Message)
        continue
    }

    if (-not $payload) { continue }

    # Ignore runs that do not have a stages array; they cannot be graphed.
    if (-not ($payload.PSObject.Properties['stages'] -and $payload.stages)) {
        continue
    }

    $runId = if ($payload.PSObject.Properties['runId'] -and $payload.runId) { [string]$payload.runId } else { '<none>' }
    $mode  = if ($payload.PSObject.Properties['mode'] -and $payload.mode)   { [string]$payload.mode }   else { '<none>' }
    $op    = if ($payload.PSObject.Properties['operation'] -and $payload.operation) { [string]$payload.operation } else { '<none>' }

    $stageNames = @()
    $stageKinds = @()
    foreach ($stage in $payload.stages) {
        if (-not $stage) { continue }
        $name = $null
        if ($stage.PSObject.Properties['name']) {
            $name = [string]$stage.name
        }
        if (-not $name) { continue }
        $stageNames += $name
        $stageKinds += (Get-StageKind -Name $name)
    }

    # Skip runs with no stage names even if a stages array exists.
    if (-not $stageNames) { continue }

    $runs += [pscustomobject]@{
        RunId      = $runId
        Mode       = $mode
        Operation  = $op
        StageNames = $stageNames
        StageKinds = $stageKinds
    }
}

if (-not $runs -or @($runs).Count -eq 0) {
    Write-Warning ("[devmode/stage-graph] No parseable dev-mode telemetry stage graphs found under '{0}'." -f $telemetryDir)
    return
}

# Expected order for well-formed stage graphs.
$orderMap = @{
    'rogue-check'     = 0
    'enable-addtoken' = 1
    'enable-prepare'  = 2
    'disable-close'   = 3
}

$analyzed = @()
$anomalyCounts = @{}

foreach ($run in $runs) {
    $anomalies = New-Object System.Collections.Generic.List[string]

    # Missing stages by mode.
    $hasAddtoken = $run.StageKinds -contains 'enable-addtoken'
    $hasPrepare  = $run.StageKinds -contains 'enable-prepare'
    $hasClose    = $run.StageKinds -contains 'disable-close'

    if ($run.Mode -eq 'enable') {
        if (-not $hasAddtoken) {
            $anomalies.Add('missing-enable-addtoken') | Out-Null
        }
        if (-not $hasPrepare) {
            $anomalies.Add('missing-enable-prepare') | Out-Null
        }
    } elseif ($run.Mode -eq 'disable') {
        if (-not $hasClose) {
            $anomalies.Add('missing-disable-close') | Out-Null
        }
    }

    # Duplicates.
    if ($hasAddtoken) {
        $countAdd = @($run.StageKinds | Where-Object { $_ -eq 'enable-addtoken' }).Count
        if ($countAdd -gt 1) { $anomalies.Add('duplicate-enable-addtoken') | Out-Null }
    }
    if ($hasPrepare) {
        $countPrep = @($run.StageKinds | Where-Object { $_ -eq 'enable-prepare' }).Count
        if ($countPrep -gt 1) { $anomalies.Add('duplicate-enable-prepare') | Out-Null }
    }
    if ($hasClose) {
        $countClose = @($run.StageKinds | Where-Object { $_ -eq 'disable-close' }).Count
        if ($countClose -gt 1) { $anomalies.Add('duplicate-disable-close') | Out-Null }
    }

    # Out-of-order detection based on orderMap for known kinds.
    $lastIndex = -1
    $outOfOrder = $false
    foreach ($kind in $run.StageKinds) {
        if (-not $orderMap.ContainsKey($kind)) { continue }
        $idx = [int]$orderMap[$kind]
        if ($lastIndex -ge 0 -and $idx -lt $lastIndex) {
            $outOfOrder = $true
            break
        }
        $lastIndex = $idx
    }
    if ($outOfOrder) {
        $anomalies.Add('out-of-order-stage-graph') | Out-Null
    }

    foreach ($a in $anomalies) {
        if (-not $anomalyCounts.ContainsKey($a)) {
            $anomalyCounts[$a] = 0
        }
        $anomalyCounts[$a]++
    }

    $analyzed += [pscustomobject]@{
        RunId         = $run.RunId
        Mode          = $run.Mode
        Operation     = $run.Operation
        StageNames    = $run.StageNames
        StageKinds    = $run.StageKinds
        IsExpectedGraph = ($anomalies.Count -eq 0)
        Anomalies     = $anomalies.ToArray()
    }
}

$anomalySummary = @()
foreach ($key in $anomalyCounts.Keys) {
    $anomalySummary += [pscustomobject]@{
        Anomaly = $key
        Count   = $anomalyCounts[$key]
    }
}

$summary = [pscustomobject]@{
    GeneratedAt     = (Get-Date).ToString('o')
    Root            = $root
    TelemetryDir    = $telemetryDir
    TotalRuns       = $runs.Count
    ExpectedGraphs  = (@($analyzed | Where-Object { $_.IsExpectedGraph })).Count
    UnexpectedGraphs = (@($analyzed | Where-Object { -not $_.IsExpectedGraph })).Count
    AnomalyKinds    = $anomalySummary
    Runs            = $analyzed
}

if (-not $OutputPath) {
    $OutputPath = Join-Path $root 'tests/results/_agent/icon-editor/dev-mode-stage-graph-summary.json'
}

$outDir = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}

$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding utf8
Write-Host ("[devmode/stage-graph] Stage graph summary written to {0}" -f $OutputPath) -ForegroundColor Cyan
