#Requires -Version 7.0
param(
    [Parameter(Mandatory)]
    [pscustomobject]$Context
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-LatestUbuntuManifestPath {
    param(
        [string]$RepoRoot,
        [psobject]$Config
    )

    $pointerSetting = $null
    if ($Config -and $Config.PSObject.Properties['UbuntuManifestPointerPath']) {
        $pointerSetting = $Config.UbuntuManifestPointerPath
    }
    if (-not $pointerSetting) {
        $pointerSetting = 'out/local-ci-ubuntu/latest.json'
    }
    $pointerPath = if ([System.IO.Path]::IsPathRooted($pointerSetting)) {
        $pointerSetting
    } else {
        Join-Path $RepoRoot $pointerSetting
    }
    if (Test-Path -LiteralPath $pointerPath -PathType Leaf) {
        try {
            $pointer = Get-Content -LiteralPath $pointerPath -Raw | ConvertFrom-Json -ErrorAction Stop
            $candidatePaths = @()
            if ($pointer.manifest) {
                $candidatePaths += $pointer.manifest
            }
            if ($pointer.manifest_rel) {
                $candidatePaths += (Join-Path $RepoRoot $pointer.manifest_rel)
            }
            if ($pointer.run_root) {
                $candidatePaths += (Join-Path $pointer.run_root 'ubuntu-run.json')
            }
            foreach ($candidate in $candidatePaths) {
                if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
                    return (Resolve-Path -LiteralPath $candidate -ErrorAction Stop).ProviderPath
                }
            }
        } catch {
            Write-Warning ("[10-Prep] Failed to parse Ubuntu pointer '{0}': {1}" -f $pointerPath, $_.Exception.Message)
        }
    }

    $searchSetting = $null
    if ($Config -and $Config.PSObject.Properties['UbuntuManifestSearchRoot']) {
        $searchSetting = $Config.UbuntuManifestSearchRoot
    }
    if (-not $searchSetting) {
        $searchSetting = 'out/local-ci-ubuntu'
    }
    $searchRoot = if ([System.IO.Path]::IsPathRooted($searchSetting)) {
        $searchSetting
    } else {
        Join-Path $RepoRoot $searchSetting
    }
    if (-not (Test-Path -LiteralPath $searchRoot -PathType Container)) {
        return $null
    }
    $directories = Get-ChildItem -LiteralPath $searchRoot -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    foreach ($dir in $directories) {
        $manifest = Join-Path $dir.FullName 'ubuntu-run.json'
        if (Test-Path -LiteralPath $manifest -PathType Leaf) {
            try {
                return (Resolve-Path -LiteralPath $manifest -ErrorAction Stop).ProviderPath
            } catch {}
        }
    }
    return $null
}

$signRoot = $Context.SignRoot
$runRoot  = $Context.RunRoot
$repoRoot = $Context.RepoRoot

Write-Host "Sign root : $signRoot"
Write-Host "Run root  : $runRoot"

if (-not (Test-Path -LiteralPath $signRoot)) {
    New-Item -ItemType Directory -Path $signRoot -Force | Out-Null
}

# Ensure local signing log folder exists; do not delete to preserve history
$localLogDir = Join-Path $signRoot 'local-signing-logs'
if (-not (Test-Path -LiteralPath $localLogDir)) {
    New-Item -ItemType Directory -Path $localLogDir -Force | Out-Null
}

# Create a working artifacts folder for this run
$artifactDir = Join-Path $runRoot 'artifacts'
if (-not (Test-Path -LiteralPath $artifactDir)) {
    New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
}

# Snapshot git status for traceability
$gitStatusPath = Join-Path $runRoot 'git-status.txt'
try {
    git -C $Context.RepoRoot status --short | Set-Content -LiteralPath $gitStatusPath -Encoding UTF8
    Write-Host "Wrote git status to $gitStatusPath"
} catch {
    "git not available; skipped status snapshot" | Set-Content -LiteralPath $gitStatusPath -Encoding UTF8
    Write-Warning "git not found in PATH; wrote placeholder to $gitStatusPath"
}

$importHint = $env:LOCALCI_IMPORT_UBUNTU_RUN
$autoImport = $true
if ($Context.Config.PSObject.Properties['AutoImportUbuntuRun']) {
    $autoImport = [bool]$Context.Config.AutoImportUbuntuRun
}
if (-not $importHint -and $autoImport) {
    $autoManifest = Get-LatestUbuntuManifestPath -RepoRoot $repoRoot -Config $Context.Config
    if ($autoManifest) {
        $importHint = $autoManifest
        Write-Host ("[10-Prep] Auto-selected Ubuntu manifest at {0}" -f $importHint) -ForegroundColor DarkGray
    } else {
        Write-Host '[10-Prep] No Ubuntu manifest discovered; set LOCALCI_IMPORT_UBUNTU_RUN to override.' -ForegroundColor DarkGray
    }
}
if ($importHint) {
    Write-Host "Attempting to import Ubuntu run metadata from $importHint"
    $importModule = Join-Path $PSScriptRoot '..' 'scripts' 'Import-UbuntuRun.psm1'
    if (-not (Test-Path -LiteralPath $importModule)) {
        throw "Import helper $importModule not found."
    }
    Import-Module -Name $importModule -Force
    $params = @{
        ManifestPath = $importHint
        RepoRoot     = $repoRoot
        RunRoot      = $runRoot
        SignRoot     = $signRoot
    }
    $skipGitEnv = $env:LOCALCI_IMPORT_SKIP_GITCHECK
    if ($skipGitEnv -and $skipGitEnv -match '^(1|true|yes)$') {
        $params.SkipGitCheck = $true
    }
    $noExtractEnv = $env:LOCALCI_IMPORT_NO_EXTRACT
    if ($noExtractEnv -and $noExtractEnv -match '^(1|true|yes)$') {
        $params.NoExtract = $true
    }
    $importResult = Invoke-UbuntuRunImport @params
    if ($importResult) {
        $coverageText = 'n/a'
        if ($importResult.Manifest.coverage) {
            $coverageText = "$($importResult.Manifest.coverage.percent)% (min $($importResult.Manifest.coverage.min_percent)%)"
        }
        Write-Host ("Imported Ubuntu run {0} with coverage {1}" -f $importResult.Manifest.timestamp, $coverageText)
    }
} else {
    Write-Host '[10-Prep] Ubuntu import skipped (no manifest selected).'
}

$envParityEnabled = $Context.Config.EnableEnvironmentParityCheck
$parityMode = ($env:LOCALCI_ENV_PARITY_MODE ?? '').ToLowerInvariant()
if ($parityMode -eq 'skip') {
    Write-Host '[10-Prep] Environment parity skipped via LOCALCI_ENV_PARITY_MODE=skip.' -ForegroundColor Yellow
    $envParityEnabled = $false
}
if ($envParityEnabled) {
    $parityScript = Join-Path $PSScriptRoot '..' 'scripts' 'Test-EnvironmentParity.ps1'
    if (-not (Test-Path -LiteralPath $parityScript -PathType Leaf)) {
        throw "[10-Prep] Environment parity script not found at $parityScript"
    }
    $profilesPath = if ($Context.Config.EnvironmentProfilesPath) { $Context.Config.EnvironmentProfilesPath } else { 'local-ci/windows/env-profiles.psd1' }
    $profileName = if ($Context.Config.EnvironmentProfile) { $Context.Config.EnvironmentProfile } else { 'labview-2021-x64' }
    $parityArgs = @(
        '-RepoRoot', $repoRoot,
        '-ProfilesPath', $profilesPath,
        '-ProfileName', $profileName
    )
    Write-Host ("[10-Prep] Verifying environment profile '{0}'" -f $profileName) -ForegroundColor Cyan
    try {
        pwsh -NoLogo -NoProfile -File $parityScript @parityArgs
    } catch {
        if ($parityMode -eq 'warn') {
            Write-Warning ("[10-Prep] Environment parity failed (warn mode): {0}" -f $_.Exception.Message)
        } else {
            throw
        }
    }
} else {
    Write-Host '[10-Prep] Environment parity check disabled.' -ForegroundColor Yellow
}
