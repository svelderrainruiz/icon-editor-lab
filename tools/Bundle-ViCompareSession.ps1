#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$StagePath,
    [string]$StageChannel,
    [string]$OutputDirectory = '.'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    param([string]$Root)
    if ([string]::IsNullOrWhiteSpace($Root)) {
        return (Resolve-Path '.').Path
    }
    return (Get-Item $Root).FullName
}

$RepoRoot = Resolve-RepoRoot -Root $RepoRoot

function Resolve-StagedArtifact {
    param(
        [string]$RepoRoot,
        [string]$PathCandidate,
        [string]$Channel
    )

    if ($PathCandidate -and (Test-Path -LiteralPath $PathCandidate -PathType Leaf)) {
        return (Resolve-Path -LiteralPath $PathCandidate).Path
    }

    $stageRoot = Join-Path $RepoRoot '.tmp-tests/xcli-stage'
    if (-not (Test-Path -LiteralPath $stageRoot -PathType Container)) {
        return $null
    }

    if (-not $Channel) {
        $Channel = $env:XCLI_STAGE_CHANNEL
    }

    if ($Channel) {
        $marker = Join-Path $stageRoot ("{0}-latest.txt" -f $Channel)
        if (Test-Path -LiteralPath $marker -PathType Leaf) {
            $path = (Get-Content -LiteralPath $marker -Raw).Trim()
            if ($path -and (Test-Path -LiteralPath $path -PathType Leaf)) {
                return (Resolve-Path -LiteralPath $path).Path
            }
        }
    }

    $latest = Get-ChildItem -LiteralPath $stageRoot -Recurse -Filter 'xcli-win-x64.zip' |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    return $latest?.FullName
}

$StageChannel = if ($StageChannel) { $StageChannel } elseif ($env:XCLI_STAGE_CHANNEL) { $env:XCLI_STAGE_CHANNEL } else { 'local' }
$stageFullPath = Resolve-StagedArtifact -RepoRoot $RepoRoot -PathCandidate $StagePath -Channel $StageChannel
if (-not $stageFullPath) {
    throw '[xcli] No staged artifact found. Run the staging task first.'
}

$stageDir = Split-Path -Parent $stageFullPath
$stageInfoPath = Join-Path $stageDir 'stage-info.json'
if (-not (Test-Path -LiteralPath $stageInfoPath -PathType Leaf)) {
    throw "[xcli] stage-info.json not found for {0}" -f $stageFullPath
}

$stageInfo = Get-Content -LiteralPath $stageInfoPath -Raw | ConvertFrom-Json
if (-not $stageInfo.PSObject.Properties['assets'] -or -not $stageInfo.assets.viCompareSession) {
    throw "[xcli] stage-info for {0} does not record a vi-compare session bundle." -f $stageFullPath
}

$sessionSource = $stageInfo.assets.viCompareSession
if (-not (Test-Path -LiteralPath $sessionSource -PathType Leaf)) {
    throw "[xcli] Vi-compare session bundle missing at {0}" -f $sessionSource
}

$outputDir = if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
    $OutputDirectory
} else {
    Join-Path $RepoRoot $OutputDirectory
}
$outputDir = [System.IO.Path]::GetFullPath($outputDir)
if (-not (Test-Path -LiteralPath $outputDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
}

$stageName = Split-Path -Leaf $stageDir
$targetName = "vi-compare-{0}.zip" -f $stageName
$targetPath = Join-Path $outputDir $targetName
Copy-Item -LiteralPath $sessionSource -Destination $targetPath -Force

Write-Host ("[[xcli]] Vi-compare session bundle copied to {0}" -f $targetPath)

[pscustomobject]@{
    StagePath       = $stageFullPath
    SessionSource   = $sessionSource
    BundlePath      = $targetPath
    StageChannel    = $StageChannel
    OutputDirectory = $outputDir
}
