#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$OutputPath,
    [string]$TelemetryDir,
    [string]$XCliSummaryPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = $env:WORKSPACE_ROOT
if (-not $root) {
    $root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..' '..') -ErrorAction Stop).ProviderPath
}

if ($TelemetryDir) {
    $telemetryDir = (Resolve-Path -LiteralPath $TelemetryDir -ErrorAction Stop).ProviderPath
} else {
    $telemetryDir = Join-Path $root 'tests/results/_agent/icon-editor/dev-mode-run'
}

if (-not (Test-Path -LiteralPath $telemetryDir -PathType Container)) {
    Write-Warning ("[devmode/outcome] Telemetry directory not found at '{0}'." -f $telemetryDir)
    return
}

if ($XCliSummaryPath) {
    $xcliSummaryPath = (Resolve-Path -LiteralPath $XCliSummaryPath -ErrorAction Stop).ProviderPath
} else {
    $xcliSummaryPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-devmode-summary.json'
}

if (-not (Test-Path -LiteralPath $xcliSummaryPath -PathType Leaf)) {
    Write-Warning ("[devmode/outcome] x-cli summary not found at '{0}'. Run Summarize-LabviewDevmodeLogs.ps1 first." -f $xcliSummaryPath)
    return
}

try {
    $xcliSummary = Get-Content -LiteralPath $xcliSummaryPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
} catch {
    Write-Warning ("[devmode/outcome] Failed to parse x-cli summary '{0}': {1}" -f $xcliSummaryPath, $_.Exception.Message)
    return
}

$xcliByRunId = @{}
if ($xcliSummary.PSObject.Properties.Match('ByRunId').Count -gt 0 -and $xcliSummary.ByRunId) {
    foreach ($run in $xcliSummary.ByRunId) {
        if ($run -and $run.PSObject.Properties.Match('RunId').Count -gt 0) {
            $key = if ($run.RunId) { [string]$run.RunId } else { '<none>' }
            $xcliByRunId[$key] = $run
        }
    }
}

$files = Get-ChildItem -LiteralPath $telemetryDir -Filter 'dev-mode-run-*.json' -File -ErrorAction SilentlyContinue
if (-not $files) {
    Write-Warning ("[devmode/outcome] No dev-mode telemetry runs found under '{0}'." -f $telemetryDir)
    return
}

$alignments = @()
$mismatches = @()

foreach ($file in $files) {
    try {
        $rec = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Warning ("[devmode/outcome] Failed to parse telemetry run '{0}': {1}" -f $file.FullName, $_.Exception.Message)
        continue
    }

    if (-not $rec) { continue }
    if (-not ($rec.PSObject.Properties['runId'])) { continue }

    $runId = [string]$rec.runId
    $provider = if ($rec.PSObject.Properties['provider']) { [string]$rec.provider } else { '<unknown>' }
    if ($provider -ne 'XCliSim') {
        continue
    }

    $status = if ($rec.PSObject.Properties['status']) { [string]$rec.status } else { '<unknown>' }
    $operation = if ($rec.PSObject.Properties['operation']) { [string]$rec.operation } else { '<none>' }
    $versions = if ($rec.PSObject.Properties['requestedVersions']) { $rec.requestedVersions } else { $null }
    $bitness  = if ($rec.PSObject.Properties['requestedBitness'])  { $rec.requestedBitness }  else { $null }

    $xcliRun = $null
    if ($xcliByRunId.ContainsKey($runId)) {
        $xcliRun = $xcliByRunId[$runId]
    }

    $xcliOutcome = '<none>'
    if ($xcliRun -and $xcliRun.PSObject.Properties.Match('Outcome').Count -gt 0) {
        $xcliOutcome = [string]$xcliRun.Outcome
    }

    $entry = [pscustomobject]@{
        RunId           = $runId
        Provider        = $provider
        Operation       = $operation
        Versions        = $versions
        Bitness         = $bitness
        TelemetryStatus = $status
        XCliOutcome     = $xcliOutcome
    }

    $alignments += $entry

    if ($xcliOutcome -ne '<none>' -and $status -ne '<unknown>' -and $xcliOutcome -ne $status) {
        $mismatches += $entry
    }
}

if (-not $OutputPath) {
    $OutputPath = Join-Path $root 'tests/results/_agent/icon-editor/dev-mode-outcome-alignment.json'
}

$outDir = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}

$summary = [pscustomobject]@{
    GeneratedAt = (Get-Date).ToString('o')
    Root        = $root
    TelemetryDir = $telemetryDir
    XCliSummaryPath = $xcliSummaryPath
    Alignments  = $alignments
    Mismatches  = $mismatches
}

$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding utf8
Write-Host ("[devmode/outcome] Alignment summary written to {0}" -f $OutputPath) -ForegroundColor Cyan

