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
    Write-Warning ("[devmode/providers] Telemetry directory not found at '{0}'." -f $telemetryDir)
    return
}

$files = Get-ChildItem -LiteralPath $telemetryDir -Filter 'dev-mode-run-*.json' -File -ErrorAction SilentlyContinue
if (-not $files) {
    Write-Warning ("[devmode/providers] No dev-mode telemetry runs found under '{0}'." -f $telemetryDir)
    return
}

$records = @()
foreach ($file in $files) {
    try {
        $payload = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $records += $payload
    } catch {
        Write-Warning ("[devmode/providers] Failed to parse telemetry run '{0}': {1}" -f $file.FullName, $_.Exception.Message)
    }
}

if (-not $records) {
    Write-Warning ("[devmode/providers] No parseable dev-mode telemetry records found under '{0}'." -f $telemetryDir)
    return
}

$comparisons = @()

foreach ($group in $records | Group-Object -Property runId) {
    $runId = if ($group.Name) { $group.Name } else { '<none>' }

    # Within a runId, further distinguish by operation.
    $byOperation = @()
    foreach ($opGroup in $group.Group | Group-Object -Property operation) {
        $operation = if ($opGroup.Name) { $opGroup.Name } else { '<none>' }

        $versions = @()
        $bitness  = @()
        $providers = @()

        foreach ($rec in $opGroup.Group) {
            $versions += $rec.requestedVersions
            $bitness  += $rec.requestedBitness

            $providers += [pscustomobject]@{
                Provider = if ($rec.PSObject.Properties['provider']) { $rec.provider } else { '<unknown>' }
                Mode     = if ($rec.PSObject.Properties['mode'])     { $rec.mode }     else { '<unknown>' }
                Status   = if ($rec.PSObject.Properties['status'])   { $rec.status }   else { '<unknown>' }
                ErrorSummary = if ($rec.PSObject.Properties['errorSummary']) { $rec.errorSummary } else { $null }
            }
        }

        $byOperation += [pscustomobject]@{
            RunId      = $runId
            Operation  = $operation
            Versions   = ($versions | Where-Object { $_ } | Sort-Object -Unique)
            Bitness    = ($bitness  | Where-Object { $_ } | Sort-Object -Unique)
            Providers  = $providers
        }
    }

    $comparisons += $byOperation
}

$summary = [pscustomobject]@{
    GeneratedAt = (Get-Date).ToString('o')
    Root        = $root
    TelemetryDir = $telemetryDir
    Comparisons  = $comparisons
}

if (-not $OutputPath) {
    $OutputPath = Join-Path $root 'tests/results/_agent/icon-editor/dev-mode-provider-summary.json'
}

$outDir = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}

$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding utf8
Write-Host ("[devmode/providers] Provider comparison summary written to {0}" -f $OutputPath) -ForegroundColor Cyan

