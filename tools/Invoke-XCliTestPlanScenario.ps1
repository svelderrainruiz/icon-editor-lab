#Requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateSet('matrix-emulated','matrix-full','release-lock-fail','override-success','qa-only')]
    [string]$Scenario,
    [string]$RepoRoot,
    [string]$StageChannel = 'ci',
    [string]$QaDestination = '.tmp-tests/xcli-qa',
    [string]$ReleaseTagOverride = ''
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

if ([string]::IsNullOrWhiteSpace($QaDestination)) {
    $QaDestination = '.tmp-tests/xcli-qa'
}

$artifactPath = Join-Path $RepoRoot 'artifacts/xcli-win-x64.zip'
if (-not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) {
    throw "[xcli] Packaged artifact not found at $artifactPath. Run the package task first."
}

function Invoke-WithEnv {
    param(
        [hashtable]$Overrides,
        [scriptblock]$Script
    )

    $backup = @{}
    foreach ($key in $Overrides.Keys) {
        $backup[$key] = if (${env:$key}) { ${env:$key} } else { $null }
        if ($Overrides[$key] -eq $null) {
            Remove-Item -Path "Env:$key" -ErrorAction SilentlyContinue
        } else {
            Set-Item -Path "Env:$key" -Value $Overrides[$key]
        }
    }

    try {
        & $Script
    } finally {
        foreach ($key in $backup.Keys) {
            if ($backup[$key] -eq $null) {
                Remove-Item -Path "Env:$key" -ErrorAction SilentlyContinue
            } else {
                Set-Item -Path "Env:$key" -Value $backup[$key]
            }
        }
    }
}

$envOverrides = @{
    XCLI_STAGE_CHANNEL          = $StageChannel
    XCLI_LABVIEW_FIXTURE_MATRIX = 'full'
    XCLI_VALIDATE_LABVIEW_SMOKE = 'matrix:full'
}

switch ($Scenario) {
    'matrix-emulated' {
        $envOverrides['XCLI_LABVIEW_FIXTURE_MATRIX'] = 'emulated'
        $envOverrides['XCLI_VALIDATE_LABVIEW_SMOKE'] = 'matrix:emulated'
    }
    'matrix-full' {
        $envOverrides['XCLI_LABVIEW_FIXTURE_MATRIX'] = 'full'
        $envOverrides['XCLI_VALIDATE_LABVIEW_SMOKE'] = 'matrix:full'
    }
}

function Invoke-StageValidatePromote {
    param(
        [string]$RepoRoot,
        [string]$StageChannel,
        [string]$QaDestination
    )

    $stageResult = & (Join-Path $RepoRoot 'tools/Stage-XCliArtifact.ps1') `
        -RepoRoot $RepoRoot `
        -ArtifactPath (Join-Path $RepoRoot 'artifacts/xcli-win-x64.zip') `
        -Channel $StageChannel `
        -Overwrite

    & (Join-Path $RepoRoot 'tools/Test-XCliReleaseAsset.ps1') `
        -RepoRoot $RepoRoot `
        -StagePath $stageResult.StagePath `
        -StageChannel $StageChannel `
        -WorkDir (Join-Path $RepoRoot '.tmp-tests/xcli-release-validation')

    & (Join-Path $RepoRoot 'tools/Promote-XCliArtifact.ps1') `
        -RepoRoot $RepoRoot `
        -StagePath $stageResult.StagePath `
        -StageChannel $StageChannel `
        -Destination $QaDestination

    return $stageResult.StagePath
}

$uploadFolder = Join-Path $RepoRoot '.tmp-tests/xcli-upload'

function Invoke-UploadStage {
    param(
        [string]$RepoRoot,
        [string]$StagePath,
        [string]$DestinationFolder,
        [string]$ReleaseTagOverride,
        [switch]$ExpectFailure
    )

    if ($StagePath) {
        $StagePath = $StagePath.Trim()
    }
    Write-Host ("[[xcli]] Upload request: stagePath={0}" -f $StagePath)

    try {
        & (Join-Path $RepoRoot 'tools/Upload-XCliArtifact.ps1') `
            -RepoRoot $RepoRoot `
            -StagePath $StagePath `
            -Mode 'folder' `
            -DestinationFolder $DestinationFolder `
            -DestinationFileName (Split-Path -Leaf $StagePath) `
            -ReleaseTag $ReleaseTagOverride
        if ($ExpectFailure) {
            throw "[[xcli]] Expected upload to fail, but it succeeded."
        }
    } catch {
        if ($ExpectFailure) {
            Write-Host ("[[xcli]] Expected upload failure captured: {0}" -f $_.Exception.Message)
        } else {
            throw
        }
    }
}

Invoke-WithEnv -Overrides $envOverrides -Script {
    switch ($Scenario) {
        'matrix-emulated' {
            $stagePath = Invoke-StageValidatePromote -RepoRoot $RepoRoot -StageChannel $StageChannel -QaDestination $QaDestination
            Invoke-UploadStage -RepoRoot $RepoRoot -StagePath $stagePath -DestinationFolder $uploadFolder -ReleaseTagOverride ''
        }
        'matrix-full' {
            $stagePath = Invoke-StageValidatePromote -RepoRoot $RepoRoot -StageChannel $StageChannel -QaDestination $QaDestination
            Invoke-UploadStage -RepoRoot $RepoRoot -StagePath $stagePath -DestinationFolder $uploadFolder -ReleaseTagOverride ''
        }
        'release-lock-fail' {
            $stagePath = Invoke-StageValidatePromote -RepoRoot $RepoRoot -StageChannel $StageChannel -QaDestination $QaDestination
            Invoke-UploadStage -RepoRoot $RepoRoot -StagePath $stagePath -DestinationFolder $uploadFolder -ReleaseTagOverride ''
            Invoke-UploadStage -RepoRoot $RepoRoot -StagePath $stagePath -DestinationFolder $uploadFolder -ReleaseTagOverride '' -ExpectFailure
        }
        'override-success' {
            $firstStage = Invoke-StageValidatePromote -RepoRoot $RepoRoot -StageChannel $StageChannel -QaDestination $QaDestination
            Invoke-UploadStage -RepoRoot $RepoRoot -StagePath $firstStage -DestinationFolder $uploadFolder -ReleaseTagOverride ''
            $secondStage = Invoke-StageValidatePromote -RepoRoot $RepoRoot -StageChannel $StageChannel -QaDestination $QaDestination
            Invoke-UploadStage -RepoRoot $RepoRoot -StagePath $secondStage -DestinationFolder $uploadFolder -ReleaseTagOverride ($ReleaseTagOverride ?? 'override-tag')
        }
        'qa-only' {
            $null = Invoke-StageValidatePromote -RepoRoot $RepoRoot -StageChannel $StageChannel -QaDestination $QaDestination
            Write-Host "[[xcli]] QA-only scenario completed (no upload attempted)."
        }
    }
}
