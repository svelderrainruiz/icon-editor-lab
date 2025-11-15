#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$OutputPath,
    [string]$DevModeDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = $env:WORKSPACE_ROOT
if (-not $root) {
    $root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..' '..') -ErrorAction Stop).ProviderPath
}

if ($DevModeDir) {
    $devmodeDir = (Resolve-Path -LiteralPath $DevModeDir -ErrorAction Stop).ProviderPath
    $xCliRoot = Split-Path -Parent (Split-Path -Parent $devmodeDir)
} else {
    $xCliRoot = Join-Path $root 'tools/x-cli-develop'
    $devmodeDir = Join-Path $xCliRoot 'temp_telemetry' 'labview-devmode'
}

if (-not (Test-Path -LiteralPath $devmodeDir -PathType Container)) {
    Write-Warning ("[x-cli/flaky] No labview-devmode telemetry directory found at '{0}'." -f $devmodeDir)
    return
}

$invocationFiles = Get-ChildItem -Path $devmodeDir -Filter 'invocations.jsonl' -File -Recurse -ErrorAction SilentlyContinue
if (-not $invocationFiles) {
    Write-Warning ("[x-cli/flaky] No labview-devmode invocation logs found under '{0}'." -f $devmodeDir)
    return
}

$records = @()
foreach ($file in $invocationFiles) {
    $lines = Get-Content -LiteralPath $file.FullName -ErrorAction SilentlyContinue
    foreach ($line in $lines) {
        if (-not $line) { continue }
        try {
            $records += (ConvertFrom-Json -InputObject $line -ErrorAction Stop)
        } catch {
            Write-Warning ("[x-cli/flaky] Failed to parse LabVIEW dev-mode record in '{0}': {1}" -f $file.FullName, $_.Exception.Message)
        }
    }
}

if (-not $records) {
    Write-Warning ("[x-cli/flaky] No labview-devmode records parsed from '{0}'." -f $devmodeDir)
    return
}

function Get-Outcome {
    param([int]$ExitCode)

    if ($PSBoundParameters.ContainsKey('ExitCode') -eq $false) { return '<none>' }
    switch ($ExitCode) {
        0     { 'succeeded'; break }
        2     { 'degraded'; break }
        130   { 'aborted'; break }
        default { 'failed'; break }
    }
}

$byScenario = @()

foreach ($group in $records | Group-Object -Property {
    if ($_ -is [psobject] -and $_.PSObject.Properties.Match('Scenario').Count -gt 0 -and $_.Scenario) {
        [string]$_.Scenario
    } else {
        '<none>'
    }
}) {
    $scenarioName = if ($group.Name) { $group.Name } else { '<none>' }

    $outcomeCounts = @{}
    $sequence = @()

    foreach ($rec in $group.Group) {
        $exit = $null
        if ($rec -is [psobject] -and $rec.PSObject.Properties.Match('ExitCode').Count -gt 0) {
            $exit = [int]$rec.ExitCode
        }

        $outcome = Get-Outcome -ExitCode $exit
        $sequence += $outcome

        if (-not $outcomeCounts.ContainsKey($outcome)) {
            $outcomeCounts[$outcome] = 0
        }
        $outcomeCounts[$outcome]++
    }

    $outcomeObjects = @()
    foreach ($key in $outcomeCounts.Keys) {
        $outcomeObjects += [pscustomobject]@{
            Outcome = $key
            Count   = $outcomeCounts[$key]
        }
    }

    $distinctOutcomes = $outcomeObjects | Where-Object { $_.Outcome -ne '<none>' }
    $isFlaky = $false
    if ($distinctOutcomes) {
        $distinctArray = @($distinctOutcomes)
        if ($distinctArray.Count -gt 1) {
            $isFlaky = $true
        }
    }

    $byScenario += [pscustomobject]@{
        Scenario        = $scenarioName
        Total           = $group.Count
        Outcomes        = $outcomeObjects
        IsFlaky         = $isFlaky
        OutcomeSequence = $sequence
    }
}

$summary = [pscustomobject]@{
    GeneratedAt  = (Get-Date).ToString('o')
    Root         = $root
    XCliRoot     = $xCliRoot
    DevmodeDir   = $devmodeDir
    TotalRecords = $records.Count
    ByScenario   = $byScenario
}

if (-not $OutputPath) {
    $OutputPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-devmode-flakiness.json'
}

$outDir = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}

$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding utf8
Write-Host ("[x-cli/flaky] Flakiness summary written to {0}" -f $OutputPath) -ForegroundColor Cyan
