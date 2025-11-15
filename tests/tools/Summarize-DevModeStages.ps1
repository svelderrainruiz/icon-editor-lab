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
    Write-Warning ("[devmode/stages] Telemetry directory not found at '{0}'." -f $telemetryDir)
    return
}

$files = Get-ChildItem -LiteralPath $telemetryDir -Filter 'dev-mode-run-*.json' -File -ErrorAction SilentlyContinue
if (-not $files) {
    Write-Warning ("[devmode/stages] No dev-mode telemetry runs found under '{0}'." -f $telemetryDir)
    return
}

$stageStats = @{}

foreach ($file in $files) {
    $payload = $null
    try {
        $payload = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Warning ("[devmode/stages] Failed to parse telemetry run '{0}': {1}" -f $file.FullName, $_.Exception.Message)
        continue
    }

    if (-not $payload.PSObject.Properties['stages']) { continue }
    foreach ($stage in $payload.stages) {
        if (-not $stage) { continue }
        $nameProp = $stage.PSObject.Properties['name']
        $durProp  = $stage.PSObject.Properties['durationSeconds']
        if (-not $nameProp -or -not $durProp) { continue }

        $name = [string]$nameProp.Value
        if ([string]::IsNullOrWhiteSpace($name)) { continue }

        $duration = 0.0
        [double]::TryParse([string]$durProp.Value, [ref]$duration) | Out-Null

        if (-not $stageStats.ContainsKey($name)) {
            $stageStats[$name] = [pscustomobject]@{
                Name       = $name
                Count      = 0
                Total      = 0.0
                Min        = [double]::MaxValue
                Max        = 0.0
                Statuses   = New-Object System.Collections.Generic.List[string]
            }
        }

        $entry = $stageStats[$name]
        $entry.Count++
        $entry.Total += $duration
        if ($duration -lt $entry.Min) { $entry.Min = $duration }
        if ($duration -gt $entry.Max) { $entry.Max = $duration }

        $statusValue = $null
        if ($stage.PSObject.Properties['status']) {
            $statusValue = [string]$stage.status
        }
        if ($statusValue) {
            $entry.Statuses.Add($statusValue) | Out-Null
        }
    }
}

if ($stageStats.Count -eq 0) {
    Write-Warning ("[devmode/stages] No stage duration data found under '{0}'." -f $telemetryDir)
    return
}

$stages = @()
foreach ($key in $stageStats.Keys) {
    $entry = $stageStats[$key]
    $avg = if ($entry.Count -gt 0) { [Math]::Round($entry.Total / $entry.Count, 2) } else { 0.0 }
    $min = if ($entry.Min -eq [double]::MaxValue) { 0.0 } else { [Math]::Round($entry.Min, 2) }
    $max = [Math]::Round($entry.Max, 2)
    $statuses = $entry.Statuses | Where-Object { $_ } | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object -Unique

    $stages += [pscustomobject]@{
        Name                 = $entry.Name
        Count                = $entry.Count
        AverageSeconds       = $avg
        MinSeconds           = $min
        MaxSeconds           = $max
        Statuses             = $statuses
    }
}

$summary = [pscustomobject]@{
    GeneratedAt  = (Get-Date).ToString('o')
    Root         = $root
    TelemetryDir = $telemetryDir
    Stages       = $stages
}

if (-not $OutputPath) {
    $OutputPath = Join-Path $root 'tests/results/_agent/icon-editor/dev-mode-stage-summary.json'
}

$outDir = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}

$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding utf8
Write-Host ("[devmode/stages] Stage timing summary written to {0}" -f $OutputPath) -ForegroundColor Cyan

