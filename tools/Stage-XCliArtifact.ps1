#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$ArtifactPath = 'artifacts/xcli-win-x64.zip',
    [string]$Destination,
    [string]$Channel = 'local',
    [switch]$Overwrite
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

function Resolve-ArtifactPath {
    param([string]$PathCandidate)

    if ([string]::IsNullOrWhiteSpace($PathCandidate)) {
        return $null
    }

    if ([System.IO.Path]::IsPathRooted($PathCandidate)) {
        if (Test-Path -LiteralPath $PathCandidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $PathCandidate).Path
        }
    } else {
        $combined = Join-Path $RepoRoot $PathCandidate
        if (Test-Path -LiteralPath $combined -PathType Leaf) {
            return (Resolve-Path -LiteralPath $combined).Path
        }
    }

    return $null
}

$artifactFullPath = Resolve-ArtifactPath -PathCandidate $ArtifactPath
if (-not $artifactFullPath) {
    throw ("[xcli] Packaged artifact not found at '{0}' (RepoRoot: {1}). Build + package x-cli first." -f $ArtifactPath, $RepoRoot)
}

if (-not (Test-Path -LiteralPath $RepoRoot)) {
    throw "[xcli] Repo root '$RepoRoot' not found."
}

$stageRoot = Join-Path $RepoRoot '.tmp-tests/xcli-stage'
if (-not (Test-Path -LiteralPath $stageRoot -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $stageRoot | Out-Null
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

$stageDir = $null
$stagePath = $null

if ($Destination) {
    $stagePath = if ([System.IO.Path]::IsPathRooted($Destination)) {
        $Destination
    } else {
        Join-Path $RepoRoot $Destination
    }
    $stagePath = [System.IO.Path]::GetFullPath($stagePath)
    $stageDir = Split-Path -Parent $stagePath
} else {
    if ([string]::IsNullOrWhiteSpace($Channel)) {
        $Channel = 'local'
    }
    $channelDir = Join-Path $stageRoot $Channel
    if (-not (Test-Path -LiteralPath $channelDir -PathType Container)) {
        New-Item -ItemType Directory -Force -Path $channelDir | Out-Null
    }
    $stageDir = Join-Path $channelDir $timestamp
    New-Item -ItemType Directory -Force -Path $stageDir | Out-Null
    $stagePath = Join-Path $stageDir 'xcli-win-x64.zip'
}

if ((Test-Path -LiteralPath $stagePath -PathType Leaf) -and -not $Overwrite) {
    throw ("[xcli] Stage file already exists at {0}. Use -Overwrite to replace it." -f $stagePath)
}

Copy-Item -LiteralPath $artifactFullPath -Destination $stagePath -Force
Write-Host ("[[xcli]] Staged artifact copied to {0}" -f $stagePath)

$stageInfo = [ordered]@{
    schema    = 'icon-editor/xcli-stage@v1'
    channel   = $Channel
    stagePath = $stagePath
    createdAt = (Get-Date).ToString('o')
    source    = $artifactFullPath
    assets    = [ordered]@{}
    statuses  = [ordered]@{
        validated  = $null
        qaPromoted = $null
        uploaded   = $null
    }
}

$stageInfoPath = Join-Path $stageDir 'stage-info.json'
$stageInfo | ConvertTo-Json -Depth 6 | Out-File -FilePath $stageInfoPath -Encoding UTF8

if ($Channel) {
    $markerPath = Join-Path $stageRoot ("{0}-latest.txt" -f $Channel)
    $stagePath | Out-File -FilePath $markerPath -Encoding UTF8
}

[pscustomobject]@{
    StagePath     = $stagePath
    StageDir      = $stageDir
    StageChannel  = $Channel
    StageInfoPath = $stageInfoPath
}
