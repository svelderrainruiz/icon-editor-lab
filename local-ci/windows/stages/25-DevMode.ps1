#Requires -Version 7.0
param(
    [Parameter(Mandatory)]
    [pscustomobject]$Context
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$helpersModule = Join-Path (Split-Path -Parent $PSScriptRoot) 'modules' 'DevModeStageHelpers.psm1'
if (-not (Test-Path -LiteralPath $helpersModule -PathType Leaf)) {
    throw "[25-DevMode] Helper module not found at $helpersModule"
}
Import-Module $helpersModule -Force
$cliIsolationModule = Join-Path (Split-Path -Parent $PSScriptRoot) 'modules' 'LabVIEWCliIsolation.psm1'
if (-not (Test-Path -LiteralPath $cliIsolationModule -PathType Leaf)) {
    throw "[25-DevMode] LabVIEW CLI isolation module not found at $cliIsolationModule"
}
Import-Module $cliIsolationModule -Force

$config = $Context.Config
if (-not $config.EnableDevModeStage) {
    Write-Host ("[25-DevMode] Stage disabled via config (EnableDevModeStage={0}); skipping." -f $config.EnableDevModeStage) -ForegroundColor Yellow
    Set-StageStatus -Context $Context -Status 'Skipped'
    return
}

$bitnessEntry = $null
if ($Context.PSObject.Properties['BitnessEntry'] -and $Context.BitnessEntry) {
    $bitnessEntry = $Context.BitnessEntry
    if ($bitnessEntry.Id) {
        Write-Host ("[25-DevMode] Targeting LabVIEW plan entry {0} (Version={1}, Bitness={2})" -f $bitnessEntry.Id, $bitnessEntry.Version, $bitnessEntry.Bitness) -ForegroundColor DarkGray
    } else {
        Write-Host ("[25-DevMode] Targeting LabVIEW plan entry Version={0}, Bitness={1}" -f $bitnessEntry.Version, $bitnessEntry.Bitness) -ForegroundColor DarkGray
    }
}

$devModeMarkerName = 'dev-mode-marker'
if ($bitnessEntry -and $bitnessEntry.Id) {
    $devModeMarkerName = "{0}-{1}" -f $devModeMarkerName, $bitnessEntry.Id
}
$devModeMarkerPath = Join-Path $Context.RunRoot ("{0}.json" -f $devModeMarkerName)
$devModeLogsRoot = Join-Path $Context.RunRoot 'devmode'
if ($bitnessEntry -and $bitnessEntry.Id) {
    $devModeLogsRoot = Join-Path $devModeLogsRoot $bitnessEntry.Id
}
if (-not (Test-Path -LiteralPath $devModeLogsRoot -PathType Container)) {
    New-Item -ItemType Directory -Path $devModeLogsRoot -Force | Out-Null
}
$disableAtEnd = $true
if ($config.PSObject.Properties['DevModeDisableAtEnd']) {
    $disableAtEnd = [bool]$config.DevModeDisableAtEnd
}

function Write-DevModeMarker {
    param(
        [string]$Path,
        [string]$RepoRoot,
        [string]$IconEditorRoot,
        [int[]]$Versions,
        [int[]]$Bitness,
        [string]$Operation,
        [string]$BitnessId
    )
    $payload = [ordered]@{
        repoRoot       = $RepoRoot
        iconEditorRoot = $IconEditorRoot
        versions       = $Versions
        bitness        = $Bitness
        operation      = $Operation
        bitnessId      = $BitnessId
        timestamp      = (Get-Date).ToString('o')
    }
    $payload | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Remove-DevModeMarker {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        Remove-Item -LiteralPath $Path -Force
    }
}

function Resolve-RepoToolScript {
    param(
        [string[]]$RelativeSegments
    )
    $candidates = @()
    $candidates += (Join-PathSegments (@($repoRoot, 'src', 'tools') + $RelativeSegments))
    $candidates += (Join-PathSegments (@($repoRoot, 'tools') + $RelativeSegments))
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    return $null
}

function Resolve-PwshBinary {
    $pwshCmd = (Get-Command pwsh -ErrorAction SilentlyContinue)
    if ($pwshCmd) {
        if ($pwshCmd.PSObject.Properties['Path']) { return $pwshCmd.Path }
        if ($pwshCmd.PSObject.Properties['Source']) { return $pwshCmd.Source }
    }
    if ($IsWindows) {
        $candidate = Join-Path $PSHOME 'pwsh.exe'
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    return 'pwsh'
}

function Invoke-PreCloseLabVIEW {
    param(
        [string]$PwshPath,
        [int[]]$Versions,
        [int[]]$Bitness,
        [bool]$AllowForceClose
    )
    Write-Host "[25-DevMode] Ensuring no rogue LabVIEW instances are running before enabling dev mode..." -ForegroundColor DarkGray
    $closeScript = Resolve-RepoToolScript -RelativeSegments @('Close-LabVIEW.ps1')
    $gracefulErrors = New-Object System.Collections.Generic.List[string]
    if ($closeScript) {
        $targets = @()
        if ($Versions -and $Versions.Count -gt 0 -and $Bitness -and $Bitness.Count -gt 0) {
            foreach ($version in $Versions) {
                foreach ($bit in $Bitness) {
                    $targets += [pscustomobject]@{
                        Version = [string]$version
                        Bitness = [string]$bit
                    }
                }
            }
        }
        if (-not $targets -or $targets.Count -eq 0) {
            $targets = @([pscustomobject]@{ Version = $null; Bitness = $null })
        }

        foreach ($target in $targets) {
            try {
                $arguments = @('-NoLogo','-NoProfile','-File',$closeScript)
                if ($target.Version) { $arguments += @('-MinimumSupportedLVVersion', $target.Version) }
                if ($target.Bitness) { $arguments += @('-SupportedBitness', ([string]$target.Bitness)) }
                & $PwshPath @arguments | Out-Null
            } catch {
                $message = ("[25-DevMode][DMO105] Close-LabVIEW attempt failed (Version={0}, Bitness={1}): {2}" -f ($target.Version ? $target.Version : 'auto'), ($target.Bitness ? $target.Bitness : 'auto'), $_.Exception.Message)
                $gracefulErrors.Add($message)
                Write-Warning $message
            }
        }
    } else {
        Write-Warning "[25-DevMode] Close-LabVIEW.ps1 not found under tools/src/tools; skipping graceful close."
    }

    $gracefulSucceeded = ($gracefulErrors.Count -eq 0)
    $forceScript = Resolve-RepoToolScript -RelativeSegments @('Force-CloseLabVIEW.ps1')
    if ($gracefulSucceeded) {
        return
    }

    if (-not $AllowForceClose) {
        Write-Warning "[25-DevMode][DMO101] Graceful close failed, but DevModeAllowForceClose/LOCALCI_DEV_MODE_FORCE_CLOSE is disabled; skipping force close."
        return
    }

    if ($forceScript) {
        try {
            & $PwshPath -NoLogo -NoProfile -File $forceScript -Quiet | Out-Null
        } catch {
            Write-Warning ("[25-DevMode][DMO110] Force-CloseLabVIEW attempt failed: {0}" -f $_.Exception.Message)
        }
    } else {
        Write-Warning "[25-DevMode] Force-CloseLabVIEW.ps1 not found under tools/src/tools; skipping force close."
    }
}

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

$cliIsolationState = $null
try {
$cliIsolationState = Enter-LabVIEWCliIsolation -RunRoot $Context.RunRoot -Label 'stage-25'
if ($cliIsolationState -and $cliIsolationState.PSObject.Properties['SessionRoot'] -and $cliIsolationState.SessionRoot) {
    Write-Host ("[25-DevMode] LabVIEW CLI session root: {0}" -f $cliIsolationState.SessionRoot) -ForegroundColor DarkGray
}
if ($cliIsolationState -and $cliIsolationState.PSObject.Properties['SessionMetadataPath'] -and $cliIsolationState.SessionMetadataPath) {
    Write-Host ("[25-DevMode] LabVIEW CLI session metadata: {0}" -f $cliIsolationState.SessionMetadataPath) -ForegroundColor DarkGray
}

$actionInfo = Resolve-LocalCiDevModeAction -RequestedAction $config.DevModeAction -DisableAtEnd:$disableAtEnd
$actionNormalized = $actionInfo.Action
if ($actionInfo.Message) {
    Write-Host $actionInfo.Message -ForegroundColor DarkYellow
}
if ($actionNormalized -eq 'skip') {
    Write-Host "[25-DevMode] DevModeAction=Skip; no changes applied." -ForegroundColor Yellow
    Set-StageStatus -Context $Context -Status 'Skipped'
    return
}

$repoRoot = $Context.RepoRoot

function Resolve-RepoPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
    }
    return (Resolve-Path -LiteralPath (Join-Path $repoRoot $Path) -ErrorAction Stop).ProviderPath
}

function Join-PathSegments {
    param(
        [Parameter(Mandatory, Position = 0, ValueFromRemainingArguments = $true)]
        [string[]]$Parts
    )
    $filtered = @()
    foreach ($part in $Parts) {
        if ([string]::IsNullOrWhiteSpace($part)) { continue }
        $filtered += $part
    }
    if ($filtered.Count -eq 0) { return '' }
    if ($filtered.Count -eq 1) { return $filtered[0] }
    return [System.IO.Path]::Combine([string[]]$filtered)
}

function Get-GitRemoteOwner {
    param([string]$Path)
    try {
        $remoteUrl = git -C $Path remote get-url origin 2>$null
    } catch {
        $remoteUrl = $null
    }
    return Get-OwnerFromRemoteUrl -Url $remoteUrl
}

function Get-OwnerFromRemoteUrl {
    param([string]$Url)
    if ([string]::IsNullOrWhiteSpace($Url)) { return $null }
    $pattern = '(?i)[/:]([^/:]+)/[^/]+?(?:\.git)?$'
    $match = [regex]::Match($Url, $pattern)
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    return $null
}

function Get-GitConfiguredUser {
    param([string]$Path)
    try {
        $name = git -C $Path config --get user.name 2>$null
    } catch {
        $name = $null
    }
    if ([string]::IsNullOrWhiteSpace($name)) { return $null }
    return ($name -replace '\s+', '')
}

function Resolve-DevModeScript {
    param([string]$FileName)
    $candidates = @(
        [System.IO.Path]::Combine($repoRoot, 'src', 'tools', 'icon-editor', $FileName),
        [System.IO.Path]::Combine($repoRoot, 'tools', 'icon-editor', $FileName)
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }
    throw "[25-DevMode] Unable to locate $FileName under src/tools or tools."
}

function Get-IconEditorVendorCandidates {
    param([string]$RepoRoot)
    $list = New-Object System.Collections.Generic.List[string]
    $labviewPath = Join-PathSegments @($RepoRoot, 'vendor', 'labview-icon-editor')
    $legacyPath  = Join-PathSegments @($RepoRoot, 'vendor', 'icon-editor')
    $list.Add($labviewPath) | Out-Null
    $list.Add($legacyPath) | Out-Null
    return $list.ToArray()
}

function Find-ExistingIconEditorRoot {
    param([string]$RepoRoot)
    foreach ($candidate in Get-IconEditorVendorCandidates -RepoRoot $RepoRoot) {
        if (Test-Path -LiteralPath $candidate -PathType Container) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    return $null
}

$versionListRaw = @()
if ($config.PSObject.Properties.Match('DevModeVersions').Count -gt 0 -and $null -ne $config.DevModeVersions) {
    if ($config.DevModeVersions -is [System.Collections.IEnumerable] -and -not ($config.DevModeVersions -is [string])) {
        $versionListRaw = @($config.DevModeVersions)
    } else {
        $versionListRaw = @($config.DevModeVersions)
    }
}
if (-not $versionListRaw -or $versionListRaw.Count -eq 0) {
    if ($config.LabVIEWVersion) {
        $versionListRaw = @($config.LabVIEWVersion)
    } else {
        $versionListRaw = @()
    }
}
$versionList = @($versionListRaw | Where-Object { $_ -ne $null } | ForEach-Object { [int]$_ })
if (-not $versionList -or $versionList.Count -eq 0) {
    throw "[25-DevMode] No LabVIEW versions specified (DevModeVersions/LabVIEWVersion)."
}
if ($bitnessEntry) {
    $versionList = @([int]$bitnessEntry.Version)
}

$bitnessListRaw = @()
if ($config.PSObject.Properties.Match('DevModeBitness').Count -gt 0 -and $null -ne $config.DevModeBitness) {
    if ($config.DevModeBitness -is [System.Collections.IEnumerable] -and -not ($config.DevModeBitness -is [string])) {
        $bitnessListRaw = @($config.DevModeBitness)
    } else {
        $bitnessListRaw = @($config.DevModeBitness)
    }
}
if (-not $bitnessListRaw -or $bitnessListRaw.Count -eq 0) {
    if ($config.LabVIEWBitness) {
        $bitnessListRaw = @($config.LabVIEWBitness)
    } else {
        $bitnessListRaw = @()
    }
}
$bitnessList = @($bitnessListRaw | Where-Object { $_ -ne $null } | ForEach-Object { [int]$_ })
if (-not $bitnessList -or $bitnessList.Count -eq 0) {
    throw "[25-DevMode] No LabVIEW bitness specified (DevModeBitness/LabVIEWBitness)."
}
if ($bitnessEntry) {
    $bitnessList = @([int]$bitnessEntry.Bitness)
}

$allowForceCloseConfig = $false
if ($config.PSObject.Properties['DevModeAllowForceClose']) {
    $allowForceCloseConfig = [bool]$config.DevModeAllowForceClose
}
$allowForceClose = Resolve-DevModeForceClosePreference -ConfiguredAllowForceClose:$allowForceCloseConfig

$operation = if ($config.DevModeOperation) { $config.DevModeOperation } else { 'MissingInProject' }
$vendorUrl = if ($config.IconEditorVendorUrl) { $config.IconEditorVendorUrl } else { $null }
$vendorRef = if ($config.IconEditorVendorRef) { $config.IconEditorVendorRef } else { 'develop' }
if (-not $vendorUrl) {
    $owner = Get-GitRemoteOwner -Path $repoRoot
    if (-not $owner) { $owner = Get-GitConfiguredUser -Path $repoRoot }
    if ([string]::IsNullOrWhiteSpace($owner)) {
        $vendorUrl = 'https://github.com/ni/labview-icon-editor.git'
    } else {
        $vendorUrl = "https://github.com/$owner/labview-icon-editor.git"
    }
}
if ([string]::IsNullOrWhiteSpace($vendorRef)) {
    $vendorRef = 'develop'
}
$iconEditorRoot = Resolve-RepoPath $config.DevModeIconEditorRoot
if (-not $iconEditorRoot) {
    $existingRoot = Find-ExistingIconEditorRoot -RepoRoot $repoRoot
    if ($existingRoot) {
        $iconEditorRoot = $existingRoot
    }
}
$vendorCandidates = @(Get-IconEditorVendorCandidates -RepoRoot $repoRoot)
Write-Host ("[25-DevMode] Vendor candidates: {0}" -f ($vendorCandidates -join ', ')) -ForegroundColor DarkGray
$defaultIconRoot = if ($vendorCandidates.Count -gt 0) { $vendorCandidates[0] } else { Join-PathSegments @($repoRoot, 'vendor', 'labview-icon-editor') }
if (-not $iconEditorRoot -and (Test-Path -LiteralPath $defaultIconRoot -PathType Container)) {
    $iconEditorRoot = (Resolve-Path -LiteralPath $defaultIconRoot).Path
}
if (-not $iconEditorRoot -and $config.AutoVendorIconEditor) {
    $syncScript = Join-PathSegments @($repoRoot, 'local-ci', 'windows', 'scripts', 'Sync-IconEditorVendor.ps1')
    if (-not (Test-Path -LiteralPath $syncScript -PathType Leaf)) {
        Write-Warning "[25-DevMode] AutoVendorIconEditor enabled but sync script not found at $syncScript."
    } else {
        $vendorArgs = @('-RepoRoot', $repoRoot, '-TargetPath', $defaultIconRoot)
        if ($vendorUrl) { $vendorArgs += @('-RemoteUrl', $vendorUrl) }
        if ($vendorRef) { $vendorArgs += @('-Ref', $vendorRef) }
        try {
            Write-Host "[25-DevMode] Auto-vendoring icon editor workspace..." -ForegroundColor Cyan
            Write-Host ("[25-DevMode] Auto-vendor target: {0}" -f $defaultIconRoot) -ForegroundColor DarkGray
            pwsh -NoLogo -NoProfile -File $syncScript @vendorArgs | Out-Host
        } catch {
            Write-Warning ("[25-DevMode] Auto-vendor attempt failed: {0}" -f $_.Exception.Message)
        }
        if (Test-Path -LiteralPath $defaultIconRoot -PathType Container) {
            $iconEditorRoot = (Resolve-Path -LiteralPath $defaultIconRoot).Path
        }
    }
}
if (-not $iconEditorRoot) {
    $expectedPaths = if ($vendorCandidates -and $vendorCandidates.Count -gt 0) { $vendorCandidates -join ' or ' } else { "vendor/labview-icon-editor" }
    Write-Warning ("[25-DevMode] Icon editor vendor checkout not found (expected under {0}); skipping dev-mode stage." -f $expectedPaths)
    Set-StageStatus -Context $Context -Status 'Skipped'
    return
}

$scriptName = if ($actionNormalized -eq 'enable') { 'Enable-DevMode.ps1' } else { 'Disable-DevMode.ps1' }
$scriptPath = Resolve-DevModeScript -FileName $scriptName

$arguments = @(
    '-NoLogo','-NoProfile','-File', $scriptPath,
    '-Operation', $operation,
    '-Versions'
)
$versionList | ForEach-Object { $arguments += [string]$_ }
$arguments += '-Bitness'
$bitnessList | ForEach-Object { $arguments += [string]$_ }

$repoRootParam = $repoRoot
if ($repoRootParam) {
    $arguments += @('-RepoRoot', $repoRootParam)
}
if ($iconEditorRoot) {
    $arguments += @('-IconEditorRoot', $iconEditorRoot)
}
if ($Context.PSObject.Properties['RunRoot'] -and $Context.RunRoot) {
    $arguments += @('-RunRoot', $Context.RunRoot)
}
if ($allowForceClose) {
    $arguments += '-AllowForceClose'
}

$pwsh = Resolve-PwshBinary

Invoke-PreCloseLabVIEW -PwshPath $pwsh -Versions $versionList -Bitness $bitnessList -AllowForceClose:$allowForceClose

$previousDevModeLogRoot = $env:LOCALCI_DEV_MODE_LOGROOT
$env:LOCALCI_DEV_MODE_LOGROOT = $devModeLogsRoot

Write-Host ("[25-DevMode] Running {0} for versions {1} ({2}-bit)" -f $scriptName, ($versionList -join ','), ($bitnessList -join ',')) -ForegroundColor Cyan
# DEBUG: output arguments if env var set
if ($env:LOCALCI_DEBUG_DEV_MODE -eq '1') {
    Write-Host "[25-DevMode] pwsh arguments:" -ForegroundColor DarkGray
    $arguments | ForEach-Object { Write-Host "  $_" }
}

# Invoke the dev-mode script and propagate failures
& $pwsh @arguments
$exitCode = $LASTEXITCODE
if ($null -ne $previousDevModeLogRoot) {
    $env:LOCALCI_DEV_MODE_LOGROOT = $previousDevModeLogRoot
} else {
    Remove-Item Env:LOCALCI_DEV_MODE_LOGROOT -ErrorAction SilentlyContinue
}
if ($exitCode -ne 0) {
$logHint = Join-Path $devModeLogsRoot 'rogue'
$latestHint = $null
if (Test-Path -LiteralPath $logHint -PathType Container) {
    $latestLog = Get-ChildItem -LiteralPath $logHint -Filter 'rogue-lv-*' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latestLog) { $latestHint = $latestLog.FullName }
}
$extra = if ($latestHint) { " Latest rogue log: $latestHint" } else { '' }
Set-StageStatus -Context $Context -Status 'Failed'
throw ("[25-DevMode][DMO200] {0} exited with code {1}. See stage log and rogue details under {2}.{3}" -f $scriptName, $exitCode, $logHint, $extra)
}

if ($actionNormalized -eq 'enable') {
    if ($disableAtEnd) {
        $bitnessIdValue = $null
        if ($bitnessEntry -and $bitnessEntry.PSObject.Properties['Id']) { $bitnessIdValue = $bitnessEntry.Id }
        Write-DevModeMarker -Path $devModeMarkerPath -RepoRoot $repoRoot -IconEditorRoot $iconEditorRoot -Versions $versionList -Bitness $bitnessList -Operation $operation -BitnessId $bitnessIdValue
    } else {
        Remove-DevModeMarker -Path $devModeMarkerPath
    }
} elseif ($actionNormalized -eq 'disable') {
    Remove-DevModeMarker -Path $devModeMarkerPath
}
Set-StageStatus -Context $Context -Status 'Succeeded'
}
finally {
    if ($cliIsolationState) {
        Exit-LabVIEWCliIsolation -Isolation $cliIsolationState
    }
}

