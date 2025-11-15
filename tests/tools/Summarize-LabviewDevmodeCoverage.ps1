#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$OutputPath,
    [string]$DevModeDir,
    [string[]]$DesiredScenarioFamilies
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
    Write-Warning ("[x-cli/coverage] No labview-devmode telemetry directory found at '{0}'." -f $devmodeDir)
    return
}

$invocationFiles = Get-ChildItem -Path $devmodeDir -Filter 'invocations.jsonl' -File -Recurse -ErrorAction SilentlyContinue
if (-not $invocationFiles) {
    Write-Warning ("[x-cli/coverage] No labview-devmode invocation logs found under '{0}'." -f $devmodeDir)
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
            Write-Warning ("[x-cli/coverage] Failed to parse labview-devmode record in '{0}': {1}" -f $file.FullName, $_.Exception.Message)
        }
    }
}

if (-not $records) {
    Write-Warning ("[x-cli/coverage] No labview-devmode records parsed from '{0}'." -f $devmodeDir)
    return
}

if (-not $DesiredScenarioFamilies -or $DesiredScenarioFamilies.Count -eq 0) {
    $DesiredScenarioFamilies = @(
        'happy-path',
        'timeout',
        'rogue',
        'partial',
        'timeout-soft',
        'partial+timeout-soft',
        'retry-success',
        'lunit'
    )
}

function Get-ScenarioFamily {
    param([string]$Scenario)

    if (-not $Scenario) { return '<none>' }
    $scenario = $Scenario.Trim()
    if (-not $scenario) { return '<none>' }

    $dotIndex = $scenario.IndexOf('.')
    if ($dotIndex -gt 0) {
        return $scenario.Substring(0, $dotIndex)
    }

    return $scenario
}

$byOpVerBit = @()

foreach ($group in $records | Group-Object -Property {
    $op = $null
    $ver = $null
    $bit = $null

    if ($_ -is [psobject]) {
        if ($_.PSObject.Properties.Match('Operation').Count -gt 0) { $op = $_.Operation }
        if ($_.PSObject.Properties.Match('LvVersion').Count -gt 0) { $ver = $_.LvVersion }
        if ($_.PSObject.Properties.Match('Bitness').Count -gt 0) { $bit = $_.Bitness }
    }

    '{0}|{1}|{2}' -f ($op ?? '<none>'), ($ver ?? '<none>'), ($bit ?? '<none>')
}) {
    $keyParts = $group.Name -split '\|', 3
    $operation = if ($keyParts.Count -ge 1) { $keyParts[0] } else { '<none>' }
    $lvVersion = if ($keyParts.Count -ge 2) { $keyParts[1] } else { '<none>' }
    $bitness   = if ($keyParts.Count -ge 3) { $keyParts[2] } else { '<none>' }

    $scenarioCounts = @()
    $familyCounts   = @()

    $scenarioGroups = $group.Group | Group-Object -Property {
        if ($_ -is [psobject] -and $_.PSObject.Properties.Match('Scenario').Count -gt 0 -and $_.Scenario) {
            [string]$_.Scenario
        } else {
            '<none>'
        }
    }

    foreach ($sg in $scenarioGroups) {
        $scenarioCounts += [pscustomobject]@{
            Scenario = $sg.Name
            Count    = $sg.Count
        }
    }

    $familyGroups = $group.Group | Group-Object -Property {
        $rawScenario = $null
        if ($_ -is [psobject] -and $_.PSObject.Properties.Match('Scenario').Count -gt 0) {
            $rawScenario = $_.Scenario
        }
        Get-ScenarioFamily -Scenario $rawScenario
    }

    foreach ($fg in $familyGroups) {
        $familyCounts += [pscustomobject]@{
            Family = $fg.Name
            Count  = $fg.Count
        }
    }

    $presentFamilies = $familyCounts | ForEach-Object { $_.Family } | Where-Object { $_ } | Sort-Object -Unique
    $missingFamilies = @()
    foreach ($fam in $DesiredScenarioFamilies) {
        if (-not $presentFamilies -or -not ($presentFamilies -contains $fam)) {
            $missingFamilies += $fam
        }
    }

    $byOpVerBit += [pscustomobject]@{
        Operation        = $operation
        LvVersion        = $lvVersion
        Bitness          = $bitness
        Total            = $group.Count
        ScenarioFamilies = $familyCounts
        FamiliesMissing  = $missingFamilies
        Scenarios        = $scenarioCounts
    }
}

$summary = [pscustomobject]@{
    GeneratedAt             = (Get-Date).ToString('o')
    Root                    = $root
    XCliRoot                = $xCliRoot
    DevmodeDir              = $devmodeDir
    TotalRecords            = $records.Count
    DesiredScenarioFamilies = $DesiredScenarioFamilies
    ByOperationVersionBitness = $byOpVerBit
}

if (-not $OutputPath) {
    $OutputPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-devmode-coverage.json'
}

$outDir = Split-Path -Parent $OutputPath -ErrorAction SilentlyContinue
if ($outDir -and -not (Test-Path -LiteralPath $outDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}

$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding utf8
Write-Host ("[x-cli/coverage] Coverage summary written to {0}" -f $OutputPath) -ForegroundColor Cyan
