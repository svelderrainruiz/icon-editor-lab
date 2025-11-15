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
    Write-Warning ("[devmode/policies] Telemetry directory not found at '{0}'." -f $telemetryDir)
    return
}

$files = Get-ChildItem -LiteralPath $telemetryDir -Filter 'dev-mode-run-*.json' -File -ErrorAction SilentlyContinue
if (-not $files) {
    Write-Warning ("[devmode/policies] No dev-mode telemetry runs found under '{0}'." -f $telemetryDir)
    return
}

$policyStats = @{}

foreach ($file in $files) {
    $payload = $null
    try {
        $payload = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Warning ("[devmode/policies] Failed to parse telemetry run '{0}': {1}" -f $file.FullName, $_.Exception.Message)
        continue
    }

    if (-not $payload) { continue }

    $policy = '<none>'
    if ($payload.PSObject.Properties['lvAddonRootMode'] -and $payload.lvAddonRootMode) {
        $policy = [string]$payload.lvAddonRootMode
    }

    $status = '<unknown>'
    if ($payload.PSObject.Properties['status'] -and $payload.status) {
        $status = [string]$payload.status
    }

    $operation = '<none>'
    if ($payload.PSObject.Properties['operation'] -and $payload.operation) {
        $operation = [string]$payload.operation
    }

    if (-not $policyStats.ContainsKey($policy)) {
        $policyStats[$policy] = @{
            Policy       = $policy
            TotalRuns    = 0
            StatusCounts = @{}
            Operations   = New-Object System.Collections.Generic.List[string]
        }
    }

    $entry = $policyStats[$policy]
    $entry.TotalRuns++

    if (-not $entry.StatusCounts.ContainsKey($status)) {
        $entry.StatusCounts[$status] = 0
    }
    $entry.StatusCounts[$status]++

    if ($operation -and -not [string]::IsNullOrWhiteSpace($operation)) {
        if (-not $entry.Operations.Contains($operation)) {
            $entry.Operations.Add($operation) | Out-Null
        }
    }
}

if ($policyStats.Count -eq 0) {
    Write-Warning ("[devmode/policies] No policy data found under '{0}'." -f $telemetryDir)
    return
}

$byPolicy = @()
foreach ($key in $policyStats.Keys) {
    $entry = $policyStats[$key]
    $statusObjects = @()
    foreach ($statusKey in $entry.StatusCounts.Keys) {
        $statusObjects += [pscustomobject]@{
            Status = $statusKey
            Count  = $entry.StatusCounts[$statusKey]
        }
    }

    $byPolicy += [pscustomobject]@{
        Policy      = $entry.Policy
        TotalRuns   = $entry.TotalRuns
        Statuses    = $statusObjects
        Operations  = ($entry.Operations | Sort-Object -Unique)
    }
}

$summary = [pscustomobject]@{
    GeneratedAt  = (Get-Date).ToString('o')
    Root         = $root
    TelemetryDir = $telemetryDir
    Policies     = $byPolicy
}

if (-not $OutputPath) {
    $OutputPath = Join-Path $root 'tests/results/_agent/icon-editor/dev-mode-policy-summary.json'
}

$outDir = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}

$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding utf8
Write-Host ("[devmode/policies] Policy summary written to {0}" -f $OutputPath) -ForegroundColor Cyan

