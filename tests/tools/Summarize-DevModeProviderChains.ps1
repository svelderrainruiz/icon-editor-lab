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
    Write-Warning ("[devmode/chains] Telemetry directory not found at '{0}'." -f $telemetryDir)
    return
}

$files = Get-ChildItem -LiteralPath $telemetryDir -Filter 'dev-mode-run-*.json' -File -ErrorAction SilentlyContinue
if (-not $files) {
    Write-Warning ("[devmode/chains] No dev-mode telemetry runs found under '{0}'." -f $telemetryDir)
    return
}

$records = @()
foreach ($file in $files) {
    try {
        $payload = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ($payload) { $records += $payload }
    } catch {
        Write-Warning ("[devmode/chains] Failed to parse telemetry run '{0}': {1}" -f $file.FullName, $_.Exception.Message)
    }
}

if (-not $records) {
    Write-Warning ("[devmode/chains] No parseable dev-mode telemetry records found under '{0}'." -f $telemetryDir)
    return
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

function Get-StageFromOperation {
    param([string]$Operation)

    if (-not $Operation) { return '<none>' }

    if ($Operation -like 'enable-addtoken-*') { return 'enable-addtoken' }
    if ($Operation -like 'enable-prepare-*')  { return 'enable-prepare' }
    if ($Operation -like 'disable-close-*')   { return 'disable-close' }
    if ($Operation -eq 'Compare')             { return 'compare' }
    if ($Operation -eq 'BuildPackage')        { return 'build-package' }
    return '<other>'
}

$runs = @()

foreach ($group in $records | Group-Object -Property {
    if ($_ -is [psobject] -and $_.PSObject.Properties['runId'] -and $_.runId) {
        [string]$_.runId
    } else {
        '<none>'
    }
}) {
    $runId = if ($group.Name) { $group.Name } else { '<none>' }

    $providersByStage = @{}
    $statusesByStage  = @{}
    $operations = @()
    $providersAll = @()

    foreach ($rec in $group.Group) {
        $op = '<none>'
        if ($rec.PSObject.Properties['operation'] -and $rec.operation) {
            $op = [string]$rec.operation
        }
        $stage = Get-StageFromOperation -Operation $op
        $provider = Get-Provider -Record $rec
        $status   = Get-Status -Record $rec

        $operations += $op
        $providersAll += $provider

        # For each stage, keep the first provider/status we see; this is enough for chain classification.
        if (-not $providersByStage.ContainsKey($stage)) {
            $providersByStage[$stage] = $provider
        }
        if (-not $statusesByStage.ContainsKey($stage)) {
            $statusesByStage[$stage] = $status
        }
    }

    $chainProviders = @()
    foreach ($stageName in @('enable-addtoken','enable-prepare','compare')) {
        if ($providersByStage.ContainsKey($stageName)) {
            $p = $providersByStage[$stageName]
            if (-not $chainProviders.Contains($p)) {
                $chainProviders += $p
            }
        }
    }

    if (-not $chainProviders) {
        # Fallback to any providers for this run.
        foreach ($p in $providersAll) {
            if (-not $chainProviders.Contains($p)) {
                $chainProviders += $p
            }
        }
    }

    $chainLabel = if ($chainProviders) { $chainProviders -join '+' } else { '<none>' }

    # Derive a simple overall outcome for the run based on statuses.
    $allStatuses = @()
    foreach ($rec in $group.Group) {
        $allStatuses += (Get-Status -Record $rec)
    }
    $allStatuses = @($allStatuses | Where-Object { $_ -and $_ -ne '<unknown>' })

    $runOutcome = '<unknown>'
    if ($allStatuses.Count -gt 0) {
        if ($allStatuses -contains 'failed') {
            $runOutcome = 'failed'
        } elseif ($allStatuses -contains 'degraded') {
            $runOutcome = 'degraded'
        } elseif ($allStatuses -contains 'aborted') {
            $runOutcome = 'aborted'
        } elseif ($allStatuses -contains 'succeeded') {
            $runOutcome = 'succeeded'
        }
    }

    $runs += [pscustomobject]@{
        RunId         = $runId
        ProviderChain = $chainLabel
        Providers     = ($providersAll | Where-Object { $_ } | Sort-Object -Unique)
        Operations    = ($operations   | Where-Object { $_ } | Sort-Object -Unique)
        Outcome       = $runOutcome
    }
}

if (-not $runs) {
    Write-Warning ("[devmode/chains] No dev-mode runs with provider information found under '{0}'." -f $telemetryDir)
    return
}

$byChain = @()
foreach ($group in $runs | Group-Object -Property ProviderChain) {
    $label = if ($group.Name) { $group.Name } else { '<none>' }
    $total = $group.Count

    $succeeded = (@($group.Group | Where-Object { $_.Outcome -eq 'succeeded' })).Count
    $degraded  = (@($group.Group | Where-Object { $_.Outcome -eq 'degraded'  })).Count
    $failed    = (@($group.Group | Where-Object { $_.Outcome -eq 'failed'    })).Count
    $aborted   = (@($group.Group | Where-Object { $_.Outcome -eq 'aborted'   })).Count
    $unknown   = $total - $succeeded - $degraded - $failed - $aborted

    $byChain += [pscustomobject]@{
        ProviderChain = $label
        TotalRuns     = $total
        Succeeded     = $succeeded
        Degraded      = $degraded
        Failed        = $failed
        Aborted       = $aborted
        Unknown       = $unknown
    }
}

$summary = [pscustomobject]@{
    GeneratedAt  = (Get-Date).ToString('o')
    Root         = $root
    TelemetryDir = $telemetryDir
    TotalRuns    = $runs.Count
    ByProviderChain = $byChain
    Runs         = $runs
}

if (-not $OutputPath) {
    $OutputPath = Join-Path $root 'tests/results/_agent/icon-editor/dev-mode-provider-chains.json'
}

$outDir = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}

$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding utf8
Write-Host ("[devmode/chains] Provider chain summary written to {0}" -f $OutputPath) -ForegroundColor Cyan

