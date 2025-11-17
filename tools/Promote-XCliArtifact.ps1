#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$StagePath,
    [string]$StageChannel,
    [string]$Destination
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

function Get-StageAssetValue {
    param(
        [object]$StageInfo,
        [string]$Name
    )

    if (-not $StageInfo.PSObject.Properties['assets']) {
        return $null
    }

    $assets = $StageInfo.assets
    if ($assets -is [System.Collections.IDictionary]) {
        return $assets[$Name]
    }

    return $assets.$Name
}

$StageChannel = if ($StageChannel) { $StageChannel } elseif ($env:XCLI_STAGE_CHANNEL) { $env:XCLI_STAGE_CHANNEL } else { 'local' }
$stageFullPath = Resolve-StagedArtifact -RepoRoot $RepoRoot -PathCandidate $StagePath -Channel $StageChannel
if (-not $stageFullPath) {
    throw '[xcli] No staged artifact found. Run the staging + validation tasks first.'
}

$stageDir = Split-Path -Parent $stageFullPath
$stageInfoPath = Join-Path $stageDir 'stage-info.json'
if (-not (Test-Path -LiteralPath $stageInfoPath -PathType Leaf)) {
    throw "[xcli] stage-info.json not found for {0}" -f $stageFullPath
}
$stageInfo = Get-Content -LiteralPath $stageInfoPath -Raw | ConvertFrom-Json

if (-not $stageInfo.statuses.validated -or $stageInfo.statuses.validated.status -ne 'passed') {
    throw "[xcli] Stage has not passed validation yet. Run the validation task first."
}

if (-not $Destination) {
    $Destination = $env:XCLI_QA_DESTINATION
}
if (-not $Destination) {
    $Destination = '.tmp-tests/xcli-qa'
}

$qaBase = if ([System.IO.Path]::IsPathRooted($Destination)) { $Destination } else { Join-Path $RepoRoot $Destination }
$qaBase = [System.IO.Path]::GetFullPath($qaBase)

if (-not (Test-Path -LiteralPath $qaBase -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $qaBase | Out-Null
}

$stageName = Split-Path -Leaf $stageDir
$qaChannelDir = Join-Path $qaBase $StageChannel
if (-not (Test-Path -LiteralPath $qaChannelDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $qaChannelDir | Out-Null
}

$targetArtifactName = "{0}-xcli-win-x64.zip" -f $stageName
$targetArtifactPath = Join-Path $qaChannelDir $targetArtifactName
Copy-Item -LiteralPath $stageFullPath -Destination $targetArtifactPath -Force
Write-Host ("[[xcli]] Promoted staged artifact to QA destination: {0}" -f $targetArtifactPath)

$validatedDiagnostics = $stageInfo.statuses.validated.diagnostics
if ($validatedDiagnostics -and (Test-Path -LiteralPath $validatedDiagnostics -PathType Leaf)) {
    $targetDiagPath = Join-Path $qaChannelDir ("{0}-xcli-diagnostics.json" -f $stageName)
    Copy-Item -LiteralPath $validatedDiagnostics -Destination $targetDiagPath -Force
    Write-Host ("[[xcli]] Copied diagnostics to {0}" -f $targetDiagPath)
} else {
    $targetDiagPath = $null
}

$qaSessionPath = $null
$sessionAsset = Get-StageAssetValue -StageInfo $stageInfo -Name 'viCompareSession'
if ($sessionAsset -and (Test-Path -LiteralPath $sessionAsset -PathType Leaf)) {
    $targetSessionName = "{0}-vi-compare-session.zip" -f $stageName
    $qaSessionPath = Join-Path $qaChannelDir $targetSessionName
    Copy-Item -LiteralPath $sessionAsset -Destination $qaSessionPath -Force
    Write-Host ("[[xcli]] Copied vi-compare session bundle to {0}" -f $qaSessionPath)
}

$stageInfo.statuses.qaPromoted = [ordered]@{
    status      = 'passed'
    promotedAt  = (Get-Date).ToString('o')
    destination = $targetArtifactPath
    diagnostics = $targetDiagPath
}
if ($qaSessionPath) {
    $stageInfo.statuses.qaPromoted.viCompareSession = $qaSessionPath
}
$stageInfo | ConvertTo-Json -Depth 8 | Out-File -FilePath $stageInfoPath -Encoding UTF8

[pscustomobject]@{
    StagePath   = $stageFullPath
    QaArtifact  = $targetArtifactPath
    QaDiagnostics = $targetDiagPath
}
