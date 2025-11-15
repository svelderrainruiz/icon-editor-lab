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

$pointerPath = Join-Path $root 'handshake/pointer.json'
$pointerInfo = $null

if (Test-Path -LiteralPath $pointerPath -PathType Leaf) {
    try {
        $raw = Get-Content -LiteralPath $pointerPath -Raw -ErrorAction Stop
        if (-not [string]::IsNullOrWhiteSpace($raw)) {
            $pointer = $raw | ConvertFrom-Json -ErrorAction Stop
            if ($pointer.PSObject.Properties['schema'] -and $pointer.schema -eq 'handshake/v1') {
                $pointerInfo = [pscustomobject]@{
                    Schema      = $pointer.schema
                    Status      = $pointer.status
                    Sequence    = $pointer.sequence
                    UbuntuStamp = $pointer.ubuntu.stamp
                    UbuntuArtifact = $pointer.ubuntu.artifact
                    UbuntuManifestRel = $pointer.ubuntu.manifest_rel
                    WindowsStatus = $pointer.windows.status
                    WindowsRunRoot = $pointer.windows.run_root
                    WindowsStamp   = $pointer.windows.stamp
                    WindowsJob     = $pointer.windows.job
                }
            } else {
                Write-Warning ("[handshake] Unexpected handshake schema in '{0}'." -f $pointerPath)
            }
        }
    } catch {
        Write-Warning ("[handshake] Failed to parse pointer '{0}': {1}" -f $pointerPath, $_.Exception.Message)
    }
} else {
    Write-Warning ("[handshake] Pointer file not found at '{0}'." -f $pointerPath)
}

$localCiRoot = Join-Path $root 'out/local-ci'
if (-not (Test-Path -LiteralPath $localCiRoot -PathType Container)) {
    Write-Warning ("[handshake] Local CI root not found at '{0}'." -f $localCiRoot)
    return
}

$runDirs = Get-ChildItem -LiteralPath $localCiRoot -Directory -ErrorAction SilentlyContinue
if (-not $runDirs) {
    Write-Warning ("[handshake] No local CI run directories found under '{0}'." -f $localCiRoot)
    return
}

$runSummaries = @()

foreach ($dir in $runDirs) {
    $runRoot = $dir.FullName
    $runMetaPath = Join-Path $runRoot 'run-metadata.json'
    if (-not (Test-Path -LiteralPath $runMetaPath -PathType Leaf)) {
        continue
    }

    $runMeta = $null
    try {
        $runMeta = Get-Content -LiteralPath $runMetaPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Warning ("[handshake] Failed to parse run metadata '{0}': {1}" -f $runMetaPath, $_.Exception.Message)
        continue
    }

    $stamp = $null
    if ($runMeta.PSObject.Properties['Timestamp']) {
        $stamp = [string]$runMeta.Timestamp
    } else {
        $stamp = Split-Path -Leaf $runRoot
    }

    $prepStatus = $null
    $viCompareStatus = $null
    $envParityFailed = $false
    $viCompareDryRun = $false

    if ($runMeta.PSObject.Properties['Stages'] -and $runMeta.Stages) {
        foreach ($stage in $runMeta.Stages) {
            if ($stage.Id -eq 10 -or ($stage.Label -and $stage.Label -like 'Prep*')) {
                $prepStatus = $stage.Status
            }
            if ($stage.Id -eq 37 -or ($stage.Label -and $stage.Label -like 'VICompare*')) {
                $viCompareStatus = $stage.Status
            }
        }
    }

    # Inspect stage logs for parity failures and VICompare dry-run mode.
    $prepLogPath = Join-Path $runRoot 'stage-10-Prep.log'
    if (Test-Path -LiteralPath $prepLogPath -PathType Leaf) {
        try {
            $match = Select-String -LiteralPath $prepLogPath -Pattern '[EnvParity] Environment parity check failed' -SimpleMatch -ErrorAction SilentlyContinue
            if ($match) {
                $envParityFailed = $true
            }
        } catch {
        }
    }

    $viCompareLogPath = Join-Path $runRoot 'stage-37-VICompare-2021-64.log'
    if (Test-Path -LiteralPath $viCompareLogPath -PathType Leaf) {
        try {
            $matchDryRun = Select-String -LiteralPath $viCompareLogPath -Pattern 'Falling back to dry-run mode.' -SimpleMatch -ErrorAction SilentlyContinue
            $matchMissingLv = Select-String -LiteralPath $viCompareLogPath -Pattern 'LabVIEW executable not found' -SimpleMatch -ErrorAction SilentlyContinue
            if ($matchDryRun -or $matchMissingLv) {
                $viCompareDryRun = $true
            }
        } catch {
        }
    }

    $importPath = Join-Path $runRoot 'ubuntu-import.json'
    $covPercent = $null
    $covMin = $null
    $covBelowMin = $null
    $ubuntuRunId = $null
    $ubuntuManifest = $null

    if (Test-Path -LiteralPath $importPath -PathType Leaf) {
        try {
            $import = Get-Content -LiteralPath $importPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            if ($import.Coverage) {
                if ($import.Coverage.PSObject.Properties['percent']) {
                    $covPercent = [double]$import.Coverage.percent
                }
                if ($import.Coverage.PSObject.Properties['min_percent']) {
                    $covMin = [double]$import.Coverage.min_percent
                }
            }
            if ($import.PSObject.Properties['RunId']) {
                $ubuntuRunId = [string]$import.RunId
            }
            if ($import.PSObject.Properties['ManifestPath']) {
                $ubuntuManifest = [string]$import.ManifestPath
            }
        } catch {
            Write-Warning ("[handshake] Failed to parse ubuntu-import '{0}': {1}" -f $importPath, $_.Exception.Message)
        }
    }

    if ($covPercent -ne $null -and $covMin -ne $null) {
        $covBelowMin = [bool]($covPercent -lt $covMin)
    }

    $hasFailure = $false

    if ($covBelowMin) {
        $hasFailure = $true
    }
    if ($prepStatus -and $prepStatus -ne 'Succeeded') {
        $hasFailure = $true
    }
    if ($viCompareStatus -and $viCompareStatus -ne 'Succeeded') {
        $hasFailure = $true
    }
    if ($envParityFailed -or $viCompareDryRun) {
        $hasFailure = $true
    }

    $runSummaries += [pscustomobject]@{
        RunRoot          = $runRoot
        Stamp            = $stamp
        PrepStatus       = $prepStatus
        VICompareStatus  = $viCompareStatus
        UbuntuRunId       = $ubuntuRunId
        UbuntuManifest    = $ubuntuManifest
        CoveragePercent   = $covPercent
        CoverageMin       = $covMin
        CoverageBelowMin  = $covBelowMin
        EnvParityFailed   = $envParityFailed
        VICompareDryRun   = $viCompareDryRun
        HasFailure        = $hasFailure
    }
}

if (-not $runSummaries) {
    Write-Warning ("[handshake] No handshake runs with metadata found under '{0}'." -f $localCiRoot)
    return
}

if (-not $OutputPath) {
    $OutputPath = Join-Path $root 'tests/results/_agent/icon-editor/handshake-summary.json'
}

$outDir = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outDir -PathType Container)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$summaryObject = [pscustomobject]@{
    schema      = 'icon-editor/handshake-summary@v1'
    generatedAt = (Get-Date).ToString('o')
    root        = $root
    pointer     = $pointerInfo
    totalRuns   = $runSummaries.Count
    runs        = $runSummaries
}

$summaryObject | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding utf8
Write-Host ("[handshake] Summary written to {0}" -f $OutputPath) -ForegroundColor Cyan
