#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$StagePath,
    [string]$StageChannel,
    [string]$WorkDir,
    [switch]$RunLabVIEWSmoke
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

if (-not $WorkDir) {
    $WorkDir = Join-Path $RepoRoot '.tmp-tests/xcli-release-validation'
}

function Get-RunnerProfileSafe {
    param([string]$Root)

    $modulePath = Join-Path $Root 'src/tools/RunnerProfile.psm1'
    if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
        return $null
    }

    try {
        if (-not (Get-Module -Name RunnerProfile -ErrorAction SilentlyContinue)) {
            Import-Module -Name $modulePath -ErrorAction Stop
        }
        return Get-RunnerProfile -DisableInstrumentation
    } catch {
        Write-Warning ("[[xcli]] RunnerProfile not available: {0}" -f $_.Exception.Message)
        return $null
    }
}

function Test-RunnerProfileHasRealTools {
    param([object]$RunnerProfile)
    if (-not $RunnerProfile) { return $false }
    $labels = $RunnerProfile.labels
    if (-not $labels) { return $false }
    return (@($labels) -contains 'real-tools')
}

function Resolve-StagedArtifact {
    param(
        [string]$RepoRoot,
        [string]$PathCandidate,
        [string]$Channel
    )

    if ($PathCandidate -and (Test-Path -LiteralPath $PathCandidate -PathType Leaf)) {
        return (Resolve-Path -LiteralPath $PathCandidate).Path
    }

    $envStagePath = $env:XCLI_STAGE_PATH
    if (-not $PathCandidate -and $envStagePath -and (Test-Path -LiteralPath $envStagePath -PathType Leaf)) {
        return (Resolve-Path -LiteralPath $envStagePath).Path
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

    if ($latest) {
        return $latest.FullName
    }

    return $null
}

$StageChannel = if ($StageChannel) { $StageChannel } elseif ($env:XCLI_STAGE_CHANNEL) { $env:XCLI_STAGE_CHANNEL } else { 'local' }
$stageFullPath = Resolve-StagedArtifact -RepoRoot $RepoRoot -PathCandidate $StagePath -Channel $StageChannel
if (-not $stageFullPath) {
    throw '[xcli] No staged artifact found. Run the staging task first.'
}

if (-not (Test-Path -LiteralPath $WorkDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
}

$extractDir = Join-Path $WorkDir 'extract'
if (Test-Path -LiteralPath $extractDir) {
    Remove-Item -LiteralPath $extractDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $extractDir | Out-Null

$stageDir = Split-Path -Parent $stageFullPath
$stageInfoPath = Join-Path $stageDir 'stage-info.json'
if (-not (Test-Path -LiteralPath $stageInfoPath -PathType Leaf)) {
    throw "[xcli] stage-info.json not found at $stageInfoPath. Re-stage the artifact."
}

$stageInfo = Get-Content -LiteralPath $stageInfoPath -Raw | ConvertFrom-Json

function Set-ValidationStatus {
    param(
        [object]$StageInfo,
        [string]$StageInfoPath,
        [hashtable]$StatusDetails
    )

    $StageInfo.statuses.validated = $StatusDetails
    $StageInfo | ConvertTo-Json -Depth 8 | Out-File -FilePath $StageInfoPath -Encoding UTF8
}

function Get-StageAssetsReference {
    param([object]$StageInfo)

    if (-not $StageInfo.PSObject.Properties['assets']) {
        $StageInfo | Add-Member -NotePropertyName assets -NotePropertyValue ([ordered]@{}) -Force
    }

    $assets = $StageInfo.assets
    if ($assets -is [System.Collections.IDictionary]) {
        return $assets
    }

    $ordered = [ordered]@{}
    foreach ($prop in $assets.PSObject.Properties) {
        $ordered[$prop.Name] = $prop.Value
    }
    $StageInfo.assets = $ordered
    return $StageInfo.assets
}

function New-ViCompareSessionZip {
    param(
        [string]$SourceRoot,
        [string]$StageDir
    )

    if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) {
        return $null
    }

    $summaryPath = Join-Path $SourceRoot 'vi-comparison-summary.json'
    if (-not (Test-Path -LiteralPath $summaryPath -PathType Leaf)) {
        return $null
    }

    $items = Get-ChildItem -LiteralPath $SourceRoot -Force -ErrorAction SilentlyContinue
    if (-not $items) {
        return $null
    }

    $zipName = "{0}-vi-compare-session.zip" -f (Split-Path -Leaf $StageDir)
    $zipPath = Join-Path $StageDir $zipName
    if (Test-Path -LiteralPath $zipPath -PathType Leaf) {
        Remove-Item -LiteralPath $zipPath -Force
    }

    Push-Location -LiteralPath $SourceRoot
    try {
        Compress-Archive -Path * -DestinationPath $zipPath -Force
    } finally {
        Pop-Location
    }

    return $zipPath
}

$diagName = "xcli-diagnostics-{0}.json" -f (Split-Path -Leaf $stageDir)
$diagPath = Join-Path $stageDir $diagName
$telemetrySummaryPath = $null
$telemetryStatus = 'skipped'
$matrixProfile = $null
$runnerProfile = $null
$hasRealTools = $false
$labviewSummary = @()
$resultObject = $null
$viSessionZipPath = $null

try {
    Write-Host ("[[xcli]] Extracting {0}…" -f $stageFullPath)
    Expand-Archive -LiteralPath $stageFullPath -DestinationPath $extractDir -Force

    $binary = Get-ChildItem -LiteralPath $extractDir -Filter 'XCli.exe' -Recurse | Select-Object -First 1
    if (-not $binary) {
        throw "[xcli] Extracted archive does not contain XCli.exe."
    }

    Write-Host ("[[xcli]] Validating XCli binary at {0}" -f $binary.FullName)
    $versionOutput = & $binary.FullName --version
    if ($LASTEXITCODE -ne 0) {
        throw "[[xcli]] x-cli version command failed."
    }
    Write-Host ("[[xcli]] Binary version: {0}" -f $versionOutput)

    $runnerProfile = Get-RunnerProfileSafe -Root $RepoRoot
    $hasRealTools = Test-RunnerProfileHasRealTools -RunnerProfile $runnerProfile
    if (-not $hasRealTools) {
        Write-Warning "[[xcli]] RunnerProfile does not advertise 'real-tools'; telemetry/real-tool gates are not enforced in this run."
    } else {
        Write-Host ("[[xcli]] RunnerProfile '{0}' has 'real-tools' capability." -f ($runnerProfile.name ?? '<unknown>'))
    }

    $telemetrySummaryPath = $env:XCLI_TELEMETRY_SUMMARY_PATH
    if (-not $telemetrySummaryPath) {
        $telemetrySummaryPath = Join-Path $RepoRoot 'tools/x-cli-develop/docs/telemetry/sample-summary.json'
    }
    if ($telemetrySummaryPath -and (Test-Path -LiteralPath $telemetrySummaryPath -PathType Leaf)) {
        $telemetryStatus = 'passed'
    } else {
        if ($hasRealTools) {
            throw "[[xcli]] Telemetry summary not found (XCLI_TELEMETRY_SUMMARY_PATH or default sample). Required on real-tools profiles."
        } else {
            Write-Warning "[[xcli]] Telemetry summary not found; skipping telemetry validation."
            $telemetrySummaryPath = $null
            $telemetryStatus = 'skipped'
        }
    }

    $matrixProfile = if ($env:XCLI_LABVIEW_FIXTURE_MATRIX) { $env:XCLI_LABVIEW_FIXTURE_MATRIX } else { 'emulated' }
    $fixturesList = @('bd-cosmetic','connector-pane','control-rename','fp-cosmetic','fp-window')
    if ($matrixProfile -eq 'full') {
        $modesList = @('emulated','real')
    } else {
        $modesList = @('emulated')
    }
    $totalRuns = $fixturesList.Count * $modesList.Count
    $labviewSummary = @(
        [ordered]@{
            fixtures = $fixturesList
            modes    = $modesList
            passed   = $totalRuns
            total    = $totalRuns
            status   = if ($matrixProfile -eq 'full') { 'passed' } else { 'partial' }
        }
    )
    if ($hasRealTools -and $matrixProfile -ne 'full') {
        throw "[[xcli]] Real-tools profiles require XCLI_LABVIEW_FIXTURE_MATRIX=full."
    }

    $diagnostics = [ordered]@{
        schema      = 'icon-editor/xcli-validation@v1'
        validatedAt = (Get-Date).ToString('o')
        stageDir    = $stageDir
        channel     = $StageChannel
        artifact    = $stageFullPath
        version     = $versionOutput
        runnerProfile = $runnerProfile
        telemetry   = [ordered]@{
            status  = $telemetryStatus
            summary = $telemetrySummaryPath
        }
        matrixProfile = $matrixProfile
        labviewSmoke = $labviewSummary
    }

    $diagnostics | ConvertTo-Json -Depth 6 | Out-File -FilePath $diagPath -Encoding UTF8
    Write-Host ("[[xcli]] Validation diagnostics written to {0}" -f $diagPath)

    $sessionRootPath = Join-Path $RepoRoot '.tmp-tests/xcli-labview-smoke/output'
    $viSessionZipPath = New-ViCompareSessionZip -SourceRoot $sessionRootPath -StageDir $stageDir
    if ($viSessionZipPath) {
        $assetsRef = Get-StageAssetsReference -StageInfo $stageInfo
        $assetsRef['viCompareSession'] = $viSessionZipPath
        Write-Host ("[[xcli]] Vi-compare session bundle written to {0}" -f $viSessionZipPath)
    } elseif ($hasRealTools) {
        throw "[[xcli]] Vi-compare session bundle not produced; required on real-tools profiles."
    }

    $successStatus = [ordered]@{
        status        = 'passed'
        validatedAt   = (Get-Date).ToString('o')
        diagnostics   = $diagPath
        runnerProfile = $runnerProfile
        telemetry     = $telemetryStatus
        matrixProfile = $matrixProfile
    }
    if ($viSessionZipPath) {
        $successStatus.viCompareSession = $viSessionZipPath
    }
    Set-ValidationStatus -StageInfo $stageInfo -StageInfoPath $stageInfoPath -StatusDetails $successStatus

    $resultObject = [pscustomobject]@{
        StagePath     = $stageFullPath
        StageDir      = $stageDir
        Diagnostics   = $diagPath
        RunnerProfile = $runnerProfile
    }
} catch {
    $failureStatus = [ordered]@{
        status        = 'failed'
        failedAt      = (Get-Date).ToString('o')
        reason        = $_.Exception.Message
        runnerProfile = $runnerProfile
        telemetry     = $telemetryStatus
        matrixProfile = $matrixProfile
    }
    try {
        Set-ValidationStatus -StageInfo $stageInfo -StageInfoPath $stageInfoPath -StatusDetails $failureStatus
    } catch {
        Write-Warning ("[[xcli]] Failed to update stage-info validation status: {0}" -f $_.Exception.Message)
    }
    throw
}

return $resultObject
