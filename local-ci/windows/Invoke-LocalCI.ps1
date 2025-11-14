#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'profile.psd1'),
    [string[]]$OnlyStages,
    [string[]]$SkipStages,
    [switch]$ListStages,
    [switch]$WhatIfStages
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
    (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).ProviderPath
}

function Import-LocalCIConfig {
    param([string]$ConfigPath)
    $defaults = @{
        SignRoot                 = 'out'
        HarnessTags              = @('tools','scripts','smoke')
        MaxSignFiles             = 500
        TimestampTimeoutSeconds  = 25
        SimulateTimestampFailure = $false
        StopOnUnstagedChanges    = $false
        DefaultSkipStages        = @()
        AutoImportUbuntuRun      = $true
        UbuntuManifestPointerPath= 'out/local-ci-ubuntu/latest.json'
        UbuntuManifestSearchRoot = 'out/local-ci-ubuntu'
    }

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        Write-Verbose "Config '$ConfigPath' not found. Using defaults."
        return $defaults
    }

    $userConfig = Import-PowerShellDataFile -LiteralPath $ConfigPath
    foreach ($key in $defaults.Keys) {
        if (-not $userConfig.ContainsKey($key)) {
            $userConfig[$key] = $defaults[$key]
        }
    }
    return $userConfig
}

function Get-StageList {
    param([string]$StagesRoot)
    if (-not (Test-Path -LiteralPath $StagesRoot)) {
        return @()
    }
    Get-ChildItem -LiteralPath $StagesRoot -Filter '*.ps1' -File | Sort-Object Name | ForEach-Object {
        $name = $_.BaseName
        if ($name -match '^(?<id>\d+)-(?<label>.+)$') {
            [pscustomobject]@{
                Id    = [int]$Matches.id
                Label = $Matches.label
                Path  = $_.FullName
            }
        } else {
            [pscustomobject]@{
                Id    = 0
                Label = $name
                Path  = $_.FullName
            }
        }
    }
}

function Should-RunStage {
    param(
        [pscustomobject]$Stage,
        [string[]]$Only,
        [string[]]$Skip
    )
    $idStr = "{0:00}" -f $Stage.Id
    $name  = $Stage.Label
    if ($Only -and ($Only -notcontains $idStr) -and ($Only -notcontains $name)) {
        return $false
    }
    if ($Skip -and (($Skip -contains $idStr) -or ($Skip -contains $name))) {
        return $false
    }
    return $true
}

function ConvertTo-Boolean {
    param(
        [Parameter(Mandatory=$false)]$Value,
        [bool]$Default = $false
    )
    if ($null -eq $Value) { return $Default }
    if ($Value -is [bool]) { return [bool]$Value }
    $text = $Value.ToString().Trim()
    if (-not $text) { return $Default }
    switch ($text.ToLowerInvariant()) {
        '1' { return $true }
        'true' { return $true }
        'yes' { return $true }
        'on' { return $true }
        '0' { return $false }
        'false' { return $false }
        'no' { return $false }
        'off' { return $false }
        default { return $Default }
    }
}

function Resolve-PathRelative {
    param(
        [string]$BasePath,
        [string]$Path
    )
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    if ([System.IO.Path]::IsPathRooted($Path)) {
        try { return (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath } catch { return $Path }
    }
    $candidate = Join-Path $BasePath $Path
    try { return (Resolve-Path -LiteralPath $candidate -ErrorAction Stop).ProviderPath } catch { return $candidate }
}

function Resolve-VendorToolsModulePath {
    param([string]$RepoRoot)
    $candidates = @(
        (Join-Path $RepoRoot 'tools/VendorTools.psm1'),
        (Join-Path $RepoRoot 'src/tools/VendorTools.psm1')
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).ProviderPath
        }
    }
    throw "VendorTools module not found under 'tools' or 'src/tools'. Checked: $($candidates -join ', ')"
}

function Get-LabVIEWBitnessPlan {
    param(
        [pscustomobject]$Config,
        [string]$RepoRoot
    )

    $versions = @()
    if ($Config.PSObject.Properties['LabVIEWVersion']) {
        $value = $Config.LabVIEWVersion
        if ($value -is [array]) { $versions = @($value | ForEach-Object { [int]$_ }) }
        else { $versions = @([int]$value) }
    }
    if ($versions.Count -eq 0) { $versions = @(2021) }

    $bitness = @()
    if ($Config.PSObject.Properties['LabVIEWBitness']) {
        $value = $Config.LabVIEWBitness
        if ($value -is [array]) { $bitness = @($value | ForEach-Object { [int]$_ }) }
        else { $bitness = @([int]$value) }
    }
    if ($bitness.Count -eq 0) { $bitness = @(64) }

    $plan = New-Object System.Collections.Generic.List[object]
    try {
        Import-Module (Resolve-VendorToolsModulePath -RepoRoot $RepoRoot) -Force -ErrorAction Stop
    } catch {
        Write-Warning ("Failed to import VendorTools module: {0}" -f $_.Exception.Message)
    }

    foreach ($version in $versions) {
        foreach ($bit in $bitness) {
            $exePath = $null
            $iniPath = $null
            $present = $false
            try {
                if (Get-Command -Name Find-LabVIEWVersionExePath -ErrorAction SilentlyContinue) {
                    $exePath = Find-LabVIEWVersionExePath -Version $version -Bitness $bit -ErrorAction Stop
                    if ($exePath) {
                        $present = $true
                        if (Get-Command -Name Get-LabVIEWIniPath -ErrorAction SilentlyContinue) {
                            $iniPath = Get-LabVIEWIniPath -LabVIEWExePath $exePath
                        }
                    }
                }
            } catch {
                Write-Warning ("Unable to resolve LabVIEW {0} ({1}-bit): {2}" -f $version, $bit, $_.Exception.Message)
            }
            $plan.Add([pscustomobject]@{
                Version        = [int]$version
                Bitness        = [int]$bit
                Id             = ("{0}-{1}" -f $version, $bit)
                LabVIEWExePath = $exePath
                LabVIEWIniPath = $iniPath
                Present        = $present
            }) | Out-Null
        }
    }
    return $plan.ToArray()
}

$repoRoot   = Get-RepoRoot
$config     = Import-LocalCIConfig -ConfigPath $ConfigPath
$stagesRoot = Join-Path $PSScriptRoot 'stages'
$stages     = Get-StageList -StagesRoot $stagesRoot
$bitnessPlan = Get-LabVIEWBitnessPlan -Config $config -RepoRoot $repoRoot

if ($ListStages) {
    if (-not $stages) {
        Write-Host "No stage scripts found under $stagesRoot"
        return
    }
    $stages | Format-Table @{n='Id';e={"{0:00}" -f $_.Id}}, Label, Path
    return
}

if (-not $stages) {
    throw "No stage scripts found under $stagesRoot. Add scripts before running the local CI."
}

# Combine skip lists (config + CLI)
$combinedSkip = @()
if ($config.DefaultSkipStages) { $combinedSkip += $config.DefaultSkipStages }
if ($SkipStages) { $combinedSkip += $SkipStages }

if ($config.StopOnUnstagedChanges) {
    try {
        $gitStatus = git -C $repoRoot status --porcelain
        if ($gitStatus) {
            throw "Working tree has unstaged changes. Commit/stash or disable StopOnUnstagedChanges."
        }
    } catch {
        Write-Warning 'git not available to check working tree status; continuing.'
    }
}

$signRoot     = Join-Path $repoRoot $config.SignRoot
if (-not (Test-Path -LiteralPath $signRoot)) {
    New-Item -ItemType Directory -Path $signRoot -Force | Out-Null
}
$ciRoot       = Join-Path $signRoot 'local-ci'
$timestamp    = Get-Date -Format 'yyyyMMdd-HHmmss'
$runRoot      = Join-Path $ciRoot $timestamp
New-Item -ItemType Directory -Path $runRoot -Force | Out-Null

$preserveRunOnFailure = ConvertTo-Boolean -Value $config.PreserveRunOnFailure -Default $true
$envPreserve = [Environment]::GetEnvironmentVariable('LOCALCI_PRESERVE_RUN')
if ($envPreserve) {
    $preserveRunOnFailure = ConvertTo-Boolean -Value $envPreserve -Default $preserveRunOnFailure
}

$archiveFailedRuns = ConvertTo-Boolean -Value $config.ArchiveFailedRuns -Default $false
$envArchive = [Environment]::GetEnvironmentVariable('LOCALCI_ARCHIVE_RUN')
if ($envArchive) {
    $archiveFailedRuns = ConvertTo-Boolean -Value $envArchive -Default $archiveFailedRuns
}
$archiveRoot = $null
if ($archiveFailedRuns) {
    $archiveRootConfig = $null
    if ($config.PSObject.Properties['FailedRunArchiveRoot']) {
        $archiveRootConfig = $config.FailedRunArchiveRoot
    }
    $archiveRoot = if ($archiveRootConfig) { Resolve-PathRelative -BasePath $repoRoot -Path $archiveRootConfig } else { Join-Path $signRoot 'local-ci-archive' }
    if (-not (Test-Path -LiteralPath $archiveRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $archiveRoot -Force | Out-Null
    }
}

function Try-GitCommand {
    param([string[]]$Args)
    try { return (git @Args 2>$null) } catch { return $null }
}

$gitCommit = Try-GitCommand -Args @('-C', $repoRoot, 'rev-parse', 'HEAD')
if (-not $gitCommit) { $gitCommit = 'unknown' }
$gitBranch = Try-GitCommand -Args @('-C', $repoRoot, 'rev-parse', '--abbrev-ref', 'HEAD')
if (-not $gitBranch) { $gitBranch = 'unknown' }

$runMeta = [ordered]@{
    RepoRoot   = $repoRoot
    SignRoot   = $signRoot
    RunRoot    = $runRoot
    Timestamp  = $timestamp
    GitCommit  = $gitCommit
    GitBranch  = $gitBranch
    Host       = $env:COMPUTERNAME
    OS         = [System.Environment]::OSVersion.VersionString
    PowerShell = $PSVersionTable.PSVersion.ToString()
    BitnessPlan = $bitnessPlan
    Stages     = @()
}

$stageResults = @()
$perBitnessStageIds = @(25, 30, 35, 36, 37, 55)
$stopStages = $false
foreach ($stage in $stages) {
    if ($stopStages) { break }

    if (-not (Should-RunStage -Stage $stage -Only $OnlyStages -Skip $combinedSkip)) {
        $stageResults += [pscustomobject]@{
            Id        = $stage.Id
            Label     = $stage.Label
            BitnessId = $null
            Status    = 'Skipped'
            LogPath   = $null
            DurationMs= 0
        }
        continue
    }

    $iterationEntries = @($null)
    if (($perBitnessStageIds -contains $stage.Id) -and $bitnessPlan -and $bitnessPlan.Count -gt 0) {
        $iterationEntries = $bitnessPlan
    }

    foreach ($bitnessEntry in $iterationEntries) {
        $bitnessId = $null
        $labelSuffix = ''
        $safeSuffix = ''
        if ($bitnessEntry) {
            $bitnessId = $bitnessEntry.Id
            $labelSuffix = " ({0})" -f $bitnessId
            $safeSuffix = "-{0}" -f ($bitnessId -replace '[^A-Za-z0-9._-]','_')
        }

        if ($WhatIfStages) {
            Write-Host ("[DRY-RUN] Would execute stage {0:00}-{1}{2}" -f $stage.Id, $stage.Label, $labelSuffix)
            $stageResults += [pscustomobject]@{
                Id        = $stage.Id
                Label     = ("{0}{1}" -f $stage.Label, $labelSuffix)
                BitnessId = $bitnessId
                Status    = 'DryRun'
                LogPath   = $null
                DurationMs= 0
            }
            $runMeta.Stages += @{
                Id        = $stage.Id
                Label     = ("{0}{1}" -f $stage.Label, $labelSuffix)
                BitnessId = $bitnessId
                Status    = 'DryRun'
                LogPath   = $null
                DurationMs= 0
                Error     = $null
            }
            continue
        }

        $logPath = Join-Path $runRoot ("stage-{0:00}-{1}{2}.log" -f $stage.Id, $stage.Label, $safeSuffix)
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $status = 'Succeeded'
        Write-Host ("==> Stage {0:00} - {1}{2}" -f $stage.Id, $stage.Label, $labelSuffix) -ForegroundColor Cyan
        Start-Transcript -Path $logPath | Out-Null
        $errorMessage = $null
        $stageContext = [pscustomobject]@{
            RepoRoot    = $repoRoot
            SignRoot    = $signRoot
            RunRoot     = $runRoot
            Config      = $config
            BitnessPlan = $bitnessPlan
            Stage       = $stage
            Timestamp   = $timestamp
            StageStatus = 'Succeeded'
        }
        if ($bitnessEntry) {
            $stageContext | Add-Member -NotePropertyName BitnessEntry -NotePropertyValue $bitnessEntry -Force
            if ($bitnessEntry.Id) {
                $stageContext | Add-Member -NotePropertyName CurrentBitnessId -NotePropertyValue $bitnessEntry.Id -Force
            }
            if ($bitnessEntry.PSObject.Properties['Version']) {
                $stageContext | Add-Member -NotePropertyName CurrentLabVIEWVersion -NotePropertyValue ([int]$bitnessEntry.Version) -Force
            }
            if ($bitnessEntry.PSObject.Properties['Bitness']) {
                $stageContext | Add-Member -NotePropertyName CurrentLabVIEWBitness -NotePropertyValue ([int]$bitnessEntry.Bitness) -Force
            }
            if ($bitnessEntry.PSObject.Properties['LabVIEWExePath']) {
                $stageContext | Add-Member -NotePropertyName CurrentLabVIEWExePath -NotePropertyValue $bitnessEntry.LabVIEWExePath -Force
            }
            if ($bitnessEntry.PSObject.Properties['LabVIEWIniPath']) {
                $stageContext | Add-Member -NotePropertyName CurrentLabVIEWIniPath -NotePropertyValue $bitnessEntry.LabVIEWIniPath -Force
            }
        }
        try {
            & $stage.Path -Context $stageContext
            if ($stageContext.PSObject.Properties['StageStatus'] -and $stageContext.StageStatus) {
                $status = $stageContext.StageStatus
            } else {
                $stageContext.StageStatus = $status
            }
        } catch {
            $status = 'Failed'
            $errorMessage = $_.Exception.Message
            Write-Error ("Stage {0:00}-{1}{2} failed: {3}" -f $stage.Id, $stage.Label, $labelSuffix, $errorMessage)
        } finally {
            Stop-Transcript | Out-Null
            $stopwatch.Stop()
        }

        $stageResults += [pscustomobject]@{
            Id         = $stage.Id
            Label      = ("{0}{1}" -f $stage.Label, $labelSuffix)
            BitnessId  = $bitnessId
            Status     = $status
            LogPath    = $logPath
            DurationMs = $stopwatch.ElapsedMilliseconds
            Error      = $errorMessage
        }

        $runMeta.Stages += @{
            Id         = $stage.Id
            Label      = ("{0}{1}" -f $stage.Label, $labelSuffix)
            BitnessId  = $bitnessId
            Status     = $status
            LogPath    = $logPath
            DurationMs = $stopwatch.ElapsedMilliseconds
            Error      = $errorMessage
        }

        if ($status -eq "Failed") {
            $stopStages = $true
            break
        }
    }
}

$runMetaPath = Join-Path $runRoot "run-metadata.json"
$runMeta | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $runMetaPath -Encoding UTF8

Write-Host ""
Write-Host "Stage summary:" -ForegroundColor Cyan
$stageResults | Select-Object Id,Label,Status,DurationMs,LogPath | Format-Table | Out-String | Write-Host

if ($stageResults | Where-Object { $_.Status -eq 'Failed' }) {
    if ($archiveFailedRuns -and $archiveRoot) {
        try {
            $archiveDest = Join-Path $archiveRoot (Split-Path -Leaf $runRoot)
            if (Test-Path -LiteralPath $archiveDest) {
                $archiveDest = Join-Path $archiveRoot ((Split-Path -Leaf $runRoot) + ('-' + (Get-Random)))
            }
            Copy-Item -Path $runRoot -Destination $archiveDest -Recurse -Force
            Write-Host ("Archived failed run to {0}" -f $archiveDest) -ForegroundColor DarkGray
        } catch {
            Write-Warning ("Failed to archive run directory: {0}" -f $_.Exception.Message)
        }
    }
    if (-not $preserveRunOnFailure) {
        try {
            Remove-Item -LiteralPath $runRoot -Recurse -Force -ErrorAction Stop
        } catch {
            Write-Warning ("Failed to delete run directory '{0}': {1}" -f $runRoot, $_.Exception.Message)
        }
    }
    throw "Local CI failed. See $runMetaPath for details."
} else {
    Write-Host "Local CI completed successfully. Metadata: $runMetaPath" -ForegroundColor Green
}
