#Requires -Version 7.0
param(
    [Parameter(Mandatory)]
    [pscustomobject]$Context
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Set-StageStatus {
    param(
        [psobject]$Context,
        [string]$Status
    )
    if (-not $Context) { return }
    if ($Context.PSObject.Properties['StageStatus']) {
        $Context.StageStatus = $Status
    } else {
        $Context | Add-Member -NotePropertyName StageStatus -NotePropertyValue $Status -Force
    }
}

function Resolve-RepoPath {
    param(
        [string]$Root,
        [string]$Path
    )
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    return (Join-Path $Root $Path)
}

function Get-EnvToggle {
    param(
        [string]$Name,
        [bool]$Current
    )
    $value = [System.Environment]::GetEnvironmentVariable($Name, 'Process')
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $Current
    }
    switch ($value.Trim().ToLowerInvariant()) {
        '1' { return $true }
        'true' { return $true }
        'yes' { return $true }
        'on' { return $true }
        '0' { return $false }
        'false' { return $false }
        'no' { return $false }
        'off' { return $false }
        default { return $Current }
    }
}

$repoRoot = $Context.RepoRoot
$runRoot  = $Context.RunRoot
$timestamp = $Context.Timestamp
$config = $Context.Config

$ubuntuArtifactsRoot = Join-Path $runRoot 'ubuntu-artifacts'
$sourceRoot = Join-Path $ubuntuArtifactsRoot 'vi-comparison'
$outputRoot = Join-Path $runRoot 'vi-comparison'
$ubuntuImportSummaryPath = Join-Path $runRoot 'ubuntu-import.json'
$ubuntuImportInfo = $null
if (Test-Path -LiteralPath $ubuntuImportSummaryPath -PathType Leaf) {
    try {
        $ubuntuImportInfo = Get-Content -LiteralPath $ubuntuImportSummaryPath -Raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Warning ("[37-VICompare] Failed to parse {0}: {1}" -f $ubuntuImportSummaryPath, $_.Exception.Message)
    }
}

$sourceRootExists = Test-Path -LiteralPath $sourceRoot -PathType Container
if (-not $sourceRootExists) {
    if (-not $ubuntuImportInfo) {
        Write-Host '[37-VICompare] No Ubuntu import metadata or artifacts detected; skipping stage. Set LOCALCI_IMPORT_UBUNTU_RUN to enable the vi-comparison handshake.' -ForegroundColor Yellow
        Set-StageStatus -Context $Context -Status 'Skipped'
        return
    }
    $extractedPath = $ubuntuImportInfo.ExtractedPath
    if (-not $extractedPath) {
        Write-Host '[37-VICompare] Ubuntu import metadata present but extraction was skipped (ExtractedPath missing); skipping stage.' -ForegroundColor Yellow
        Set-StageStatus -Context $Context -Status 'Skipped'
        return
    }
    throw "Ubuntu vi-comparison artifacts not found at $sourceRoot (expected from $extractedPath). Stage 10 should have extracted local-ci-artifacts.zip into RunRoot/ubuntu-artifacts; verify extraction succeeded."
}

if (Test-Path -LiteralPath $outputRoot) {
    Remove-Item -LiteralPath $outputRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null

$candidates = Get-ChildItem -LiteralPath $sourceRoot -Directory | Sort-Object Name -Descending
if (-not $candidates) {
    throw "No vi-comparison payloads found under $sourceRoot."
}

$selected = $candidates[0]
$selectedName = $selected.Name
Write-Host "Using Ubuntu vi-comparison payload '$selectedName'"

Copy-Item -Path (Join-Path $selected.FullName '*') -Destination $outputRoot -Recurse -Force

$requestsPath = Join-Path $outputRoot 'vi-diff-requests.json'

$cliConfig = [ordered]@{
    Enabled       = $true
    ForceDryRun   = $false
    LabVIEWPath   = $null
    HarnessPath   = $null
    MaxPairs      = 25
    Timeout       = 900
    NoiseProfile  = 'full'
}

if ($config.PSObject.Properties['EnableViCompareCli']) {
    $cliConfig.Enabled = [bool]$config.EnableViCompareCli
}
if ($config.PSObject.Properties['ViCompareLabVIEWPath']) {
    $cliConfig.LabVIEWPath = $config.ViCompareLabVIEWPath
}
if ($config.PSObject.Properties['ViCompareHarnessPath']) {
    $cliConfig.HarnessPath = Resolve-RepoPath -Root $repoRoot -Path $config.ViCompareHarnessPath
}
if ($config.PSObject.Properties['ViCompareMaxPairs']) {
    $cliConfig.MaxPairs = [int]$config.ViCompareMaxPairs
}
if ($config.PSObject.Properties['ViCompareTimeoutSeconds']) {
    $cliConfig.Timeout = [int]$config.ViCompareTimeoutSeconds
}
if ($config.PSObject.Properties['ViCompareNoiseProfile']) {
    $cliConfig.NoiseProfile = [string]$config.ViCompareNoiseProfile
}

$cliConfig.Enabled = Get-EnvToggle -Name 'LOCALCI_VICOMPARE_CLI_ENABLED' -Current $cliConfig.Enabled
$cliConfig.ForceDryRun = Get-EnvToggle -Name 'LOCALCI_VICOMPARE_FORCE_DRYRUN' -Current $cliConfig.ForceDryRun

$requestsPath = Join-Path $outputRoot 'vi-diff-requests.json'
$summaryPath  = Join-Path $outputRoot 'vi-comparison-summary.json'
if (-not (Test-Path -LiteralPath $requestsPath)) {
    throw "vi-diff-requests.json missing in the selected payload."
}
if (-not (Test-Path -LiteralPath $summaryPath)) {
    throw "vi-comparison-summary.json missing in the selected payload."
}

if ($cliConfig.Enabled -and (Test-Path -LiteralPath $requestsPath -PathType Leaf)) {
    $cliScript = Join-Path $repoRoot 'local-ci/windows/scripts/Invoke-ViCompareLabVIEWCli.ps1'
    if (Test-Path -LiteralPath $cliScript -PathType Leaf) {
        $probeRoots = @(
            $selected.FullName,
            $sourceRoot,
            $repoRoot
        ) | Where-Object { $_ }
        $cliParams = @{
            RepoRoot       = $repoRoot
            RequestsPath   = $requestsPath
            OutputRoot     = $outputRoot
            ProbeRoots     = $probeRoots
            LabVIEWExePath = ($cliConfig.LabVIEWPath ?? '')
            MaxPairs       = $cliConfig.MaxPairs
            TimeoutSeconds = $cliConfig.Timeout
            NoiseProfile   = $cliConfig.NoiseProfile
        }
        $harness = $cliConfig.HarnessPath
        if (-not $harness) {
            $harness = Join-Path $repoRoot 'src/tools/TestStand-CompareHarness.ps1'
        }
        $cliParams['HarnessScript'] = $harness
        if ($cliConfig.ForceDryRun) {
            $cliParams['DryRun'] = $true
        }

        Write-Host "[vi-compare] Invoking LabVIEW CLI helper for requests at $requestsPath"
        & $cliScript @cliParams
    } else {
        Write-Warning "[vi-compare] LabVIEW CLI helper not found at $cliScript; skipping CLI execution."
    }
} elseif (-not $cliConfig.Enabled) {
    Write-Host "[vi-compare] LabVIEW CLI execution disabled; reusing imported payload."
}

$sharedRoot = Join-Path $Context.SignRoot 'vi-comparison'
$windowsSharedRoot = Join-Path $sharedRoot 'windows'
$sharedDir = Join-Path $windowsSharedRoot $timestamp
if (Test-Path -LiteralPath $sharedDir) {
    Remove-Item -LiteralPath $sharedDir -Recurse -Force
}
New-Item -ItemType Directory -Path $sharedDir -Force | Out-Null
Copy-Item -Path (Join-Path $outputRoot '*') -Destination $sharedDir -Recurse -Force

$publish = [ordered]@{
    schema        = 'vi-compare/publish@v1'
    ubuntuPayload = $selectedName
    windowsRun    = $timestamp
    generatedAtUtc= (Get-Date).ToUniversalTime().ToString('o')
    paths = @{
        runRoot = @{
            root     = $outputRoot
            summary  = $summaryPath
            requests = $requestsPath
        }
        shared = @{
            root     = $sharedDir
            summary  = Join-Path $sharedDir 'vi-comparison-summary.json'
            requests = Join-Path $sharedDir 'vi-diff-requests.json'
            relative = Join-Path 'out/vi-comparison/windows' $timestamp
        }
    }
}

$publishPathRun = Join-Path $outputRoot 'publish.json'
$publish | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $publishPathRun -Encoding UTF8

$publishPathShared = Join-Path $sharedDir 'publish.json'
$publish | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $publishPathShared -Encoding UTF8

$latestPointer = Join-Path $windowsSharedRoot 'latest.json'
$publish | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $latestPointer -Encoding UTF8

$ubuntuRunPath = $null
if ($ubuntuImportInfo -and $ubuntuImportInfo.ManifestPath) {
    try {
        $ubuntuRunPath = Split-Path -Parent $ubuntuImportInfo.ManifestPath
    } catch {
        Write-Warning ("Failed to derive ubuntu run path from manifest '{0}': {1}" -f $ubuntuImportInfo.ManifestPath, $_.Exception.Message)
    }
}

if ($ubuntuRunPath -and (Test-Path -LiteralPath $ubuntuRunPath -PathType Container)) {
    $ubuntuWindowsDir = Join-Path $ubuntuRunPath 'windows'
    if (-not (Test-Path -LiteralPath $ubuntuWindowsDir)) {
        New-Item -ItemType Directory -Path $ubuntuWindowsDir -Force | Out-Null
    }
    $runPublishPath = Join-Path $ubuntuWindowsDir 'vi-compare.publish.json'
    Copy-Item -Path $publishPathShared -Destination $runPublishPath -Force
    $markerPath = Join-Path $ubuntuWindowsDir '_PUBLISHED.json'
    $marker = [ordered]@{
        windowsRun     = $timestamp
        publishedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        publishPath    = $runPublishPath
    }
    $marker | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $markerPath -Encoding UTF8
    $readyPath = Join-Path $ubuntuRunPath '_READY'
    Remove-Item -LiteralPath $readyPath -Force -ErrorAction SilentlyContinue
    $claimPath = Join-Path $ubuntuRunPath 'windows.claimed'
    if (Test-Path -LiteralPath $claimPath -PathType Leaf) {
        try {
            $claimInfoRaw = Get-Content -LiteralPath $claimPath -Raw | ConvertFrom-Json -ErrorAction Stop
            $claimInfo = [ordered]@{}
            if ($claimInfoRaw) {
                foreach ($prop in $claimInfoRaw.PSObject.Properties) {
                    $claimInfo[$prop.Name] = $prop.Value
                }
            }
        } catch {
            $claimInfo = [ordered]@{}
        }
        $claimInfo.windowsRun = $timestamp
        $claimInfo.completedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        $claimInfo.state = 'published'
        $claimInfo.publishPath = $runPublishPath
        $claimInfo | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $claimPath -Encoding UTF8
    }
}

Write-Host "Windows vi-comparison artifacts prepared at $outputRoot"
Write-Host "Shared copy: $sharedDir"
Write-Host "Publish summary: $publishPathShared"
