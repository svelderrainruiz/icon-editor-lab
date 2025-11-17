#Requires -Version 7.0
[CmdletBinding()]
param(
    [switch]$ProbeCli
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $IsWindows) {
    throw 'This helper is intended for Windows hosts only.'
}

$scriptDir = Split-Path -Parent $PSCommandPath
if (-not $scriptDir) { throw 'Unable to determine script directory.' }
$repoRoot = Split-Path -Parent $scriptDir
if (-not $repoRoot) { throw 'Unable to determine repository root.' }

$config = $null
$configPath = $null
$configCandidates = @(
    (Join-Path $repoRoot 'configs\labview-paths.local.json')
    (Join-Path $repoRoot 'configs\labview-paths.json')
)
foreach ($candidate in $configCandidates) {
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { continue }
    try {
        $config = Get-Content -LiteralPath $candidate -Raw | ConvertFrom-Json -Depth 8

$schemaPath = Join-Path $PSScriptRoot 'configs/schema/vi-diff-heuristics.schema.json'
if (Test-Path -LiteralPath $schemaPath) {
  ($cfgContent) | Test-Json -SchemaFile $schemaPath -ErrorAction Stop
}
        $configPath = $candidate
        break
    } catch {
        $message = "Failed to parse labview-paths config at {0}: {1}" -f $candidate, $_.Exception.Message
        throw $message
    }
}

<#
.SYNOPSIS
Get-VersionedConfigValue: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Get-VersionedConfigValue {

    # ShouldProcess guard: honor -WhatIf / -Confirm
    if (-not $PSCmdlet.ShouldProcess($MyInvocation.MyCommand.Name, 'Execute')) { return }
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

    param(
        $Config,
        [string]$PropertyName
    )

    if (-not $Config) { return $null }
    $versionsProp = $Config.PSObject.Properties['versions']
    if (-not $versionsProp) { return $null }
    $versionsNode = $versionsProp.Value
    if (-not $versionsNode) { return $null }

    $enumerate = @()
    if ($versionsNode -is [System.Collections.IDictionary]) {
        foreach ($key in $versionsNode.Keys) {
            $enumerate += [pscustomobject]@{ Name = $key; Value = $versionsNode[$key] }
        }
    } else {
        $enumerate = $versionsNode.PSObject.Properties
    }

    foreach ($versionEntry in $enumerate) {
        $bitnessNode = $versionEntry.Value
        if (-not $bitnessNode) { continue }

        $bitnessEntries = @()
        if ($bitnessNode -is [System.Collections.IDictionary]) {
            foreach ($key in $bitnessNode.Keys) {
                $bitnessEntries += [pscustomobject]@{ Name = $key; Value = $bitnessNode[$key] }
            }
        } else {
            $bitnessEntries = $bitnessNode.PSObject.Properties
        }

        foreach ($bitnessEntry in $bitnessEntries) {
            $valueNode = $bitnessEntry.Value
            if (-not $valueNode) { continue }
            if ($valueNode -is [System.Collections.IDictionary]) {
                if ($valueNode.Contains($PropertyName)) { return $valueNode[$PropertyName] }
            } else {
                $valueProp = $valueNode.PSObject.Properties[$PropertyName]
                if ($valueProp -and $valueProp.Value) { return $valueProp.Value }
            }
        }
    }

    return $null
}

<#
.SYNOPSIS
Resolve-CandidatePath: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Resolve-CandidatePath {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

    param(
        [string]$PathValue
    )
    if ([string]::IsNullOrWhiteSpace($PathValue)) { return $null }
    $expanded = [Environment]::ExpandEnvironmentVariables($PathValue.Trim())
    try {
        $resolved = (Resolve-Path -LiteralPath $expanded -ErrorAction Stop).Path
        return $resolved
    } catch {
        return $expanded
    }
}

$paths = [ordered]@{
    LabVIEWExePath  = $null
    LVComparePath   = $null
    LabVIEWCLIPath  = $null
    ConfigSource    = if ($config) { $configPath } else { $null }
}

if ($config) {
    if ($config.PSObject.Properties['LabVIEWExePath'])  { $paths.LabVIEWExePath = Resolve-CandidatePath $config.LabVIEWExePath }
    if ($config.PSObject.Properties['LVComparePath'])   { $paths.LVComparePath  = Resolve-CandidatePath $config.LVComparePath }
    if ($config.PSObject.Properties['LabVIEWCLIPath'])  { $paths.LabVIEWCLIPath = Resolve-CandidatePath $config.LabVIEWCLIPath }

    if (-not $paths.LabVIEWExePath) {
        $versionValue = Get-VersionedConfigValue -Config $config -PropertyName 'LabVIEWExePath'
        if ($versionValue) { $paths.LabVIEWExePath = Resolve-CandidatePath $versionValue }
    }
    if (-not $paths.LVComparePath) {
        $versionValue = Get-VersionedConfigValue -Config $config -PropertyName 'LVComparePath'
        if ($versionValue) { $paths.LVComparePath = Resolve-CandidatePath $versionValue }
    }
    if (-not $paths.LabVIEWCLIPath) {
        $versionValue = Get-VersionedConfigValue -Config $config -PropertyName 'LabVIEWCLIPath'
        if ($versionValue) { $paths.LabVIEWCLIPath = Resolve-CandidatePath $versionValue }
    }
}

$defaultRoots = @(
    'C:\Program Files\National Instruments\LabVIEW 2025',
    'C:\Program Files\National Instruments\LabVIEW 2024',
    'C:\Program Files\National Instruments\LabVIEW 2023'
)

<#
.SYNOPSIS
Ensure-Path: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Ensure-Path {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

    param(
        [string]$Key,
        [string]$Candidate
    )
    if (-not [string]::IsNullOrWhiteSpace($paths[$Key])) { return }
    if ([string]::IsNullOrWhiteSpace($Candidate)) { return }
    $resolved = Resolve-CandidatePath $Candidate
    $paths[$Key] = $resolved
}

foreach ($root in $defaultRoots) {
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }
    Ensure-Path -Key 'LabVIEWExePath' -Candidate (Join-Path $root 'LabVIEW.exe')
    Ensure-Path -Key 'LVComparePath'  -Candidate (Join-Path $root 'Shared\LabVIEW Compare\LVCompare.exe')
    Ensure-Path -Key 'LabVIEWCLIPath' -Candidate (Join-Path $root 'Shared\LabVIEW CLI\LabVIEWCLI.exe')
}

if (-not $paths.LabVIEWCLIPath) {
    $cmd = Get-Command LabVIEWCLI.exe -ErrorAction SilentlyContinue
    if ($cmd) {
        $paths.LabVIEWCLIPath = $cmd.Source
    }
}

$missing = @()
foreach ($key in @('LabVIEWExePath','LVComparePath','LabVIEWCLIPath')) {
    $candidate = $paths[$key]
    if (-not $candidate) {
        $missing += $key
        continue
    }
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        $missing += $key
    }
}

if ($missing.Count -gt 0) {
    Write-Warning "The following required paths are missing or invalid:"
    foreach ($key in $missing) {
        Write-Warning ("  {0}: {1}" -f $key, ($paths[$key] ?? '(not set)'))
    }
    Write-Warning "Update configs\labview-paths.local.json (or configs\labview-paths.json) or install the LabVIEW CLI components, then re-run this check."
    exit 1
}

Write-Host ''
Write-Host 'LabVIEW/LVCompare configuration:' -ForegroundColor Cyan
Write-Host ("  LabVIEWExePath : {0}" -f $paths.LabVIEWExePath)
Write-Host ("  LVComparePath  : {0}" -f $paths.LVComparePath)
Write-Host ("  LabVIEWCLIPath : {0}" -f $paths.LabVIEWCLIPath)
if ($paths.ConfigSource) {
    Write-Host ("  Config file    : {0}" -f $paths.ConfigSource)
}
Write-Host ''

if ($ProbeCli.IsPresent) {
    Write-Host 'Probing LabVIEW CLI...'
    $cliLeaf = [System.IO.Path]::GetFileName($paths.LabVIEWCLIPath)
    if ($cliLeaf -eq 'LabVIEWCLI.exe') {
        throw "Direct LabVIEWCLI.exe probes are not allowed here. Route CLI verification through tools/codex/Invoke-LabVIEWOperation.ps1 and the corresponding x-cli workflow (for example, vi-compare-verify or vi-analyzer-verify)."
    }
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $paths.LabVIEWCLIPath
    $psi.ArgumentList.Add('--help')
    $psi.WorkingDirectory = $repoRoot
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    if ($proc.ExitCode -ne 0) {
        Write-Host $stdout
        Write-Host $stderr
        throw "LabVIEW CLI probe (--help) exited with code $($proc.ExitCode). Inspect output above."
    }
    Write-Host 'LabVIEW CLI responded to --help successfully.' -ForegroundColor Green
}

Write-Host 'LVCompare setup verified.' -ForegroundColor Green

[pscustomobject]@{
    LabVIEWExePath = $paths.LabVIEWExePath
    LVComparePath  = $paths.LVComparePath
    LabVIEWCLIPath = $paths.LabVIEWCLIPath
    ConfigSource   = $paths.ConfigSource
}

<#
.SYNOPSIS
Test-ValidLabel: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Test-ValidLabel {
  param([Parameter(Mandatory)][string]$Label)
  if ($Label -notmatch '^[A-Za-z0-9._-]{1,64}$') { throw "Invalid label: $Label" }
}

<#
.SYNOPSIS
Invoke-WithTimeout: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Invoke-WithTimeout {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][scriptblock]$ScriptBlock,
    [Parameter()][int]$TimeoutSec = 600
  )
  $job = Start-Job -ScriptBlock $ScriptBlock
  if (-not (Wait-Job $job -Timeout $TimeoutSec)) {
    try { Stop-Job $job -Force } catch {}
    throw "Operation timed out in $TimeoutSec s"
  }
  Receive-Job $job -ErrorAction Stop
}
