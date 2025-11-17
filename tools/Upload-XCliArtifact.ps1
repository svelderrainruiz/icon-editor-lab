#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$StagePath,
    [ValidateSet('github','folder')]
    [string]$Mode = 'github',
    [string]$ReleaseRepo = '',
    [string]$ReleaseTag = '',
    [string]$DestinationFolder = '',
    [string]$DestinationFileName = ''
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

function Resolve-StagedArtifact {
    param(
        [string]$RepoRoot,
        [string]$PathCandidate
    )

    if ($PathCandidate -and (Test-Path -LiteralPath $PathCandidate -PathType Leaf)) {
        return (Resolve-Path -LiteralPath $PathCandidate).Path
    }

    $envStagePath = $env:XCLI_STAGE_PATH
    if ($envStagePath -and (Test-Path -LiteralPath $envStagePath -PathType Leaf)) {
        return (Resolve-Path -LiteralPath $envStagePath).Path
    }

    $stageRoot = Join-Path $RepoRoot '.tmp-tests/xcli-stage'
    if (-not (Test-Path -LiteralPath $stageRoot -PathType Container)) {
        return $null
    }

    $candidates = Get-ChildItem -LiteralPath $stageRoot -Recurse -Filter 'xcli-win-x64.zip' |
        Sort-Object LastWriteTime -Descending
    foreach ($candidate in $candidates) {
        $candidateDir = Split-Path -Parent $candidate.FullName
        $infoPath = Join-Path $candidateDir 'stage-info.json'
        if (Test-Path -LiteralPath $infoPath -PathType Leaf) {
            return $candidate.FullName
        }
    }

    return $null
}

$stageFullPath = Resolve-StagedArtifact -RepoRoot $RepoRoot -PathCandidate $StagePath
Write-Host ("[[xcli]] Upload helper resolved stage: {0}" -f ($stageFullPath ?? '<none>'))
if (-not $stageFullPath) {
    throw '[xcli] No staged artifact found. Run the staging task first.'
}

$stageDir = Split-Path -Parent $stageFullPath
$stageInfoPath = Join-Path $stageDir 'stage-info.json'
if (-not (Test-Path -LiteralPath $stageInfoPath -PathType Leaf)) {
    throw "[xcli] stage-info.json not found for {0}" -f $stageFullPath
}
$stageInfo = Get-Content -LiteralPath $stageInfoPath -Raw | ConvertFrom-Json

if (-not $stageInfo.statuses.validated -or $stageInfo.statuses.validated.status -ne 'passed') {
    throw '[xcli] Cannot upload: validation gate not satisfied.'
}
if (-not $stageInfo.statuses.qaPromoted -or $stageInfo.statuses.qaPromoted.status -ne 'passed') {
    throw '[xcli] Cannot upload: QA gate not satisfied.'
}
if ($stageInfo.statuses.uploaded -and $stageInfo.statuses.uploaded.status -eq 'passed') {
    throw '[xcli] Stage already uploaded; re-stage before attempting another upload.'
}

$runnerProfile = $stageInfo.statuses.validated.runnerProfile
$sessionAsset = Get-StageAssetValue -StageInfo $stageInfo -Name 'viCompareSession'
function Test-RunnerProfileHasRealTools {
    param([object]$RunnerProfile)
    if (-not $RunnerProfile) { return $false }
    $labels = $RunnerProfile.labels
    if (-not $labels) { return $false }
    return (@($labels) -contains 'real-tools')
}

$hasRealTools = Test-RunnerProfileHasRealTools -RunnerProfile $runnerProfile

switch ($Mode) {
    'github' {
        if (-not $ReleaseRepo) {
            throw 'ReleaseRepo is required for GitHub upload mode.'
        }
        $tag = if ($ReleaseTag) { $ReleaseTag } else { Split-Path -Leaf $stageDir }
        if (-not $hasRealTools) {
            Write-Warning ("[[xcli]] RunnerProfile lacks 'real-tools'; GitHub upload is proceeding but does not satisfy the real-tools gate (tag: {0})." -f $tag)
        }
        Write-Host ("[[xcli]] (dry-run) Uploading {0} to {1}/{2} via gh (not implemented in local helper)." -f $stageFullPath, $ReleaseRepo, $tag)
        if ($sessionAsset -and (Test-Path -LiteralPath $sessionAsset -PathType Leaf)) {
            Write-Host ("[[xcli]] (dry-run) Would upload vi-compare session {0} to {1}/{2}." -f (Split-Path -Leaf $sessionAsset), $ReleaseRepo, $tag)
        }
        $uploadDetails = [ordered]@{
            status     = 'passed'
            uploadedAt = (Get-Date).ToString('o')
            mode       = 'github'
            releaseRepo = $ReleaseRepo
            releaseTag  = $tag
        }
        if ($sessionAsset) {
            $uploadDetails.viCompareSession = Split-Path -Leaf $sessionAsset
        }
    }
    'folder' {
        if (-not $DestinationFolder) {
            throw 'DestinationFolder is required for folder upload mode.'
        }
        $destinationFullPath = if ([System.IO.Path]::IsPathRooted($DestinationFolder)) {
            $DestinationFolder
        } else {
            Join-Path $RepoRoot $DestinationFolder
        }
        if (-not (Test-Path -LiteralPath $destinationFullPath -PathType Container)) {
            New-Item -ItemType Directory -Force -Path $destinationFullPath | Out-Null
        }
        $targetFileName = if ($DestinationFileName) { $DestinationFileName } else { Split-Path -Leaf $stageFullPath }
        $targetPath = Join-Path $destinationFullPath $targetFileName
        Copy-Item -LiteralPath $stageFullPath -Destination $targetPath -Force
        Write-Host ("[[xcli]] Copied staged artifact to {0}" -f $targetPath)
        $sessionCopyPath = $null
        if ($sessionAsset -and (Test-Path -LiteralPath $sessionAsset -PathType Leaf)) {
            $sessionLeaf = Split-Path -Leaf $sessionAsset
            $sessionCopyPath = Join-Path $destinationFullPath $sessionLeaf
            Copy-Item -LiteralPath $sessionAsset -Destination $sessionCopyPath -Force
            Write-Host ("[[xcli]] Copied vi-compare session bundle to {0}" -f $sessionCopyPath)
        }
        $uploadDetails = [ordered]@{
            status      = 'passed'
            uploadedAt  = (Get-Date).ToString('o')
            mode        = 'folder'
            destination = $targetPath
        }
        if ($sessionCopyPath) {
            $uploadDetails.viCompareSession = $sessionCopyPath
        }
    }
}

$stageInfo.statuses.uploaded = $uploadDetails
$stageInfo | ConvertTo-Json -Depth 8 | Out-File -FilePath $stageInfoPath -Encoding UTF8

[pscustomobject]@{
    StagePath  = $stageFullPath
    UploadInfo = $uploadDetails
}
