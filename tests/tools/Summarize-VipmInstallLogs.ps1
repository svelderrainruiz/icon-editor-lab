#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$OutputPath,
    [string]$LogRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = $env:WORKSPACE_ROOT
if (-not $root) {
    $root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..' '..') -ErrorAction Stop).ProviderPath
}

if ($LogRoot) {
    $vipmRoot = (Resolve-Path -LiteralPath $LogRoot -ErrorAction Stop).ProviderPath
} else {
    $vipmRoot = Join-Path $root 'tests/results/_agent/icon-editor/vipm-install'
}

if (-not (Test-Path -LiteralPath $vipmRoot -PathType Container)) {
    Write-Warning ("[vipm] VIPM install log root not found at '{0}'." -f $vipmRoot)
    return
}

$installFiles = Get-ChildItem -LiteralPath $vipmRoot -Filter 'vipm-install-*.json' -File -ErrorAction SilentlyContinue
if (-not $installFiles) {
    Write-Warning ("[vipm] No vipm-install logs found under '{0}'." -f $vipmRoot)
    return
}

$installRecords = @()
foreach ($file in $installFiles) {
    try {
        $rec = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if (-not $rec) { continue }
        if ($rec.PSObject.Properties['schema'] -and $rec.schema -ne 'icon-editor/vipm-install@v1') {
            continue
        }
        $installRecords += [pscustomobject]@{
            FilePath       = $file.FullName
            Provider       = if ($rec.PSObject.Properties['provider'])       { [string]$rec.provider }       else { '<unknown>' }
            LabVIEWVersion = if ($rec.PSObject.Properties['labviewVersion']) { [string]$rec.labviewVersion } else { '<unknown>' }
            LabVIEWBitness = if ($rec.PSObject.Properties['labviewBitness']) { [string]$rec.labviewBitness } else { '<unknown>' }
            ExitCode       = if ($rec.PSObject.Properties['exitCode'])       { [int]$rec.exitCode }          else { 0 }
            StdErr         = if ($rec.PSObject.Properties['stderr'])         { [string]$rec.stderr }         else { '' }
            GeneratedAt    = if ($rec.PSObject.Properties['generatedAt'])    { [string]$rec.generatedAt }    else { $null }
        }
    } catch {
        Write-Warning ("[vipm] Failed to parse vipm-install log '{0}': {1}" -f $file.FullName, $_.Exception.Message)
    }
}

if (-not $installRecords) {
    Write-Warning ("[vipm] No valid vipm-install records parsed under '{0}'." -f $vipmRoot)
    return
}

$byKey = @()
foreach ($group in $installRecords | Group-Object -Property Provider, LabVIEWVersion, LabVIEWBitness) {
    $provider = $group.Group[0].Provider
    $ver      = $group.Group[0].LabVIEWVersion
    $bit      = $group.Group[0].LabVIEWBitness

    $total    = $group.Count
    $success  = ($group.Group | Where-Object { $_.ExitCode -eq 0 }).Count
    $failed   = ($group.Group | Where-Object { $_.ExitCode -ne 0 }).Count

    $last     = $group.Group | Sort-Object GeneratedAt, FilePath | Select-Object -Last 1
    $lastCode = $last.ExitCode
    $lastErr  = $last.StdErr
    if ($lastErr -and $lastErr.Length -gt 400) {
        $lastErr = $lastErr.Substring(0, 400)
    }

    $byKey += [pscustomobject]@{
        Provider       = $provider
        LabVIEWVersion = $ver
        LabVIEWBitness = $bit
        TotalRuns      = $total
        Succeeded      = $success
        Failed         = $failed
        LastExitCode   = $lastCode
        LastErrorSample = $lastErr
    }
}

$recentFailures = @()
$failedRecords = $installRecords | Where-Object { $_.ExitCode -ne 0 } | Sort-Object GeneratedAt, FilePath
foreach ($rec in ($failedRecords | Select-Object -Last 10)) {
    $err = $rec.StdErr
    if ($err -and $err.Length -gt 400) {
        $err = $err.Substring(0, 400)
    }
    $recentFailures += [pscustomobject]@{
        Provider       = $rec.Provider
        LabVIEWVersion = $rec.LabVIEWVersion
        LabVIEWBitness = $rec.LabVIEWBitness
        ExitCode       = $rec.ExitCode
        ErrorSnippet   = $err
        FilePath       = $rec.FilePath
    }
}

$installedRoot = $vipmRoot
$installedFiles = Get-ChildItem -LiteralPath $installedRoot -Filter 'vipm-installed-*.json' -File -ErrorAction SilentlyContinue
$installedSummary = $null
if ($installedFiles) {
    $installedRecords = @()
    foreach ($file in $installedFiles) {
        try {
            $rec = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            if (-not $rec) { continue }
            if ($rec.PSObject.Properties['schema'] -and $rec.schema -ne 'icon-editor/vipm-installed@v1') {
                continue
            }
            $installedRecords += [pscustomobject]@{
                FilePath       = $file.FullName
                LabVIEWVersion = if ($rec.PSObject.Properties['labviewVersion']) { [string]$rec.labviewVersion } else { '<unknown>' }
                LabVIEWBitness = if ($rec.PSObject.Properties['labviewBitness']) { [string]$rec.labviewBitness } else { '<unknown>' }
                PackageCount   = if ($rec.PSObject.Properties['packages'] -and $rec.packages) { @($rec.packages).Count } else { 0 }
            }
        } catch {
            Write-Warning ("[vipm] Failed to parse vipm-installed log '{0}': {1}" -f $file.FullName, $_.Exception.Message)
        }
    }

    if ($installedRecords) {
        $byInstalled = @()
        foreach ($group in $installedRecords | Group-Object -Property LabVIEWVersion, LabVIEWBitness) {
            $ver = $group.Group[0].LabVIEWVersion
            $bit = $group.Group[0].LabVIEWBitness
            $total = $group.Count
            $avgPackages = 0
            if ($total -gt 0) {
                $avgPackages = [Math]::Round(($group.Group | Measure-Object -Property PackageCount -Average).Average, 2)
            }

            $byInstalled += [pscustomobject]@{
                LabVIEWVersion = $ver
                LabVIEWBitness = $bit
                TotalSnapshots = $total
                AveragePackages = $avgPackages
            }
        }

        $installedSummary = $byInstalled
    }
}

if (-not $OutputPath) {
    $OutputPath = Join-Path $root 'tests/results/_agent/icon-editor/vipm-install-summary.json'
}

$outDir = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}

$summary = [pscustomobject]@{
    GeneratedAt   = (Get-Date).ToString('o')
    Root          = $root
    VipmRoot      = $vipmRoot
    TotalRuns     = $installRecords.Count
    ByProviderVersion = $byKey
    RecentFailures    = $recentFailures
    InstalledSnapshots = $installedSummary
}

$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding utf8
Write-Host ("[vipm] Install summary written to {0}" -f $OutputPath) -ForegroundColor Cyan

