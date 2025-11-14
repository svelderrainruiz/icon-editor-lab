#Requires -Version 7.0
param(
    [Parameter(Mandatory)]
    [pscustomobject]$Context
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$helpersModule = Join-Path (Split-Path -Parent $PSScriptRoot) 'modules' 'DevModeStageHelpers.psm1'
if (-not (Test-Path -LiteralPath $helpersModule -PathType Leaf)) {
    throw "[55-DevModeCleanup] Helper module not found at $helpersModule"
}
Import-Module $helpersModule -Force
$cliIsolationModule = Join-Path (Split-Path -Parent $PSScriptRoot) 'modules' 'LabVIEWCliIsolation.psm1'
if (-not (Test-Path -LiteralPath $cliIsolationModule -PathType Leaf)) {
    throw "[55-DevModeCleanup] LabVIEW CLI isolation module not found at $cliIsolationModule"
}
Import-Module $cliIsolationModule -Force

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

function Resolve-DevModeScript {
    param(
        [string]$RepoRoot,
        [string]$FileName
    )
    $candidates = @(
        [System.IO.Path]::Combine($RepoRoot, 'src', 'tools', 'icon-editor', $FileName),
        [System.IO.Path]::Combine($RepoRoot, 'tools', 'icon-editor', $FileName)
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }
    throw "[55-DevModeCleanup] Unable to locate $FileName under src/tools or tools."
}

$config = $Context.Config
$disableAtEnd = $true
if ($config.PSObject.Properties['DevModeDisableAtEnd']) {
    $disableAtEnd = [bool]$config.DevModeDisableAtEnd
}
$allowForceCloseConfig = $false
if ($config.PSObject.Properties['DevModeAllowForceClose']) {
    $allowForceCloseConfig = [bool]$config.DevModeAllowForceClose
}
$allowForceClose = Resolve-DevModeForceClosePreference -ConfiguredAllowForceClose:$allowForceCloseConfig

if (-not $disableAtEnd) {
    Write-Host "[55-DevModeCleanup] DevModeDisableAtEnd=$disableAtEnd; skipping." -ForegroundColor Yellow
    Set-StageStatus -Context $Context -Status 'Skipped'
    return
}

$bitnessEntry = $null
if ($Context.PSObject.Properties['BitnessEntry'] -and $Context.BitnessEntry) {
    $bitnessEntry = $Context.BitnessEntry
    if ($bitnessEntry.Id) {
        Write-Host ("[55-DevModeCleanup] Targeting LabVIEW plan entry {0} (Version={1}, Bitness={2})" -f $bitnessEntry.Id, $bitnessEntry.Version, $bitnessEntry.Bitness) -ForegroundColor DarkGray
    } else {
        Write-Host ("[55-DevModeCleanup] Targeting LabVIEW plan entry Version={0}, Bitness={1}" -f $bitnessEntry.Version, $bitnessEntry.Bitness) -ForegroundColor DarkGray
    }
}

$markerName = 'dev-mode-marker'
if ($bitnessEntry -and $bitnessEntry.Id) {
    $markerName = "{0}-{1}" -f $markerName, $bitnessEntry.Id
}
$markerPath = Join-Path $Context.RunRoot ("{0}.json" -f $markerName)
if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
    Write-Host '[55-DevModeCleanup] No dev-mode marker found; skipping disable.' -ForegroundColor Yellow
    Set-StageStatus -Context $Context -Status 'Skipped'
    return
}

try {
    $marker = Get-Content -LiteralPath $markerPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
} catch {
    throw "[55-DevModeCleanup] Failed to read dev-mode marker: $($_.Exception.Message)"
}

if ($bitnessEntry) {
    $versions = @([int]$bitnessEntry.Version)
    $bitness  = @([int]$bitnessEntry.Bitness)
} else {
    $versions = @($marker.versions | ForEach-Object { [int]$_ })
    $bitness  = @($marker.bitness  | ForEach-Object { [int]$_ })
    if (-not $versions -or $versions.Count -eq 0) {
        throw '[55-DevModeCleanup] Marker missing LabVIEW versions.'
    }
    if (-not $bitness -or $bitness.Count -eq 0) {
        throw '[55-DevModeCleanup] Marker missing LabVIEW bitness.'
    }
}

$operation = if ($marker.operation) { $marker.operation } elseif ($config.DevModeOperation) { $config.DevModeOperation } else { 'MissingInProject' }
$iconEditorRoot = if ($marker.iconEditorRoot) { $marker.iconEditorRoot } else { $config.DevModeIconEditorRoot }
$repoRoot = $Context.RepoRoot

$scriptPath = Resolve-DevModeScript -RepoRoot $repoRoot -FileName 'Disable-DevMode.ps1'

$arguments = @(
    '-NoLogo','-NoProfile','-File', $scriptPath,
    '-Operation', $operation,
    '-Versions'
)
$versions | ForEach-Object { $arguments += [string]$_ }
$arguments += '-Bitness'
$bitness | ForEach-Object { $arguments += [string]$_ }
if ($repoRoot) { $arguments += @('-RepoRoot', $repoRoot) }
if ($iconEditorRoot) { $arguments += @('-IconEditorRoot', $iconEditorRoot) }
if ($Context.PSObject.Properties['RunRoot'] -and $Context.RunRoot) {
    $arguments += @('-RunRoot', $Context.RunRoot)
}
if ($allowForceClose) {
    $arguments += '-AllowForceClose'
}

$pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue)
if ($pwsh) {
    if ($pwsh.PSObject.Properties['Path']) { $pwsh = $pwsh.Path }
    elseif ($pwsh.PSObject.Properties['Source']) { $pwsh = $pwsh.Source }
}
if (-not $pwsh -and $IsWindows) {
    $candidate = Join-Path $PSHOME 'pwsh.exe'
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { $pwsh = $candidate }
}
if (-not $pwsh) { $pwsh = 'pwsh' }

$cliIsolationState = $null
try {
$cliIsolationState = Enter-LabVIEWCliIsolation -RunRoot $Context.RunRoot -Label 'stage-55'
if ($cliIsolationState -and $cliIsolationState.PSObject.Properties['SessionRoot'] -and $cliIsolationState.SessionRoot) {
    Write-Host ("[55-DevModeCleanup] LabVIEW CLI session root: {0}" -f $cliIsolationState.SessionRoot) -ForegroundColor DarkGray
}
if ($cliIsolationState -and $cliIsolationState.PSObject.Properties['SessionMetadataPath'] -and $cliIsolationState.SessionMetadataPath) {
    Write-Host ("[55-DevModeCleanup] LabVIEW CLI session metadata: {0}" -f $cliIsolationState.SessionMetadataPath) -ForegroundColor DarkGray
}

Write-Host ("[55-DevModeCleanup] Running Disable-DevMode.ps1 for versions {0} ({1}-bit)" -f ($versions -join ','), ($bitness -join ',')) -ForegroundColor Cyan
& $pwsh @arguments
$exitCode = $LASTEXITCODE
if ($exitCode -ne 0) {
    throw ("[55-DevModeCleanup] Disable-DevMode.ps1 exited with code {0}." -f $exitCode)
}

Remove-Item -LiteralPath $markerPath -Force
}
finally {
    if ($cliIsolationState) {
        Exit-LabVIEWCliIsolation -Isolation $cliIsolationState
    }
}
