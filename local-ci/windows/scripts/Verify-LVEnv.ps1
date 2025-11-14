#Requires -Version 7.0
[CmdletBinding()]
param(
  [switch]$ProbeCli,
  [string]$OutputRoot = 'out/windows-lvenv'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $IsWindows) { throw 'Verify-LVEnv.ps1 is intended for Windows hosts.' }

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..')).ProviderPath
$verifyLvCompare = Join-Path $repoRoot 'src/tools/Verify-LVCompareSetup.ps1'
if (-not (Test-Path -LiteralPath $verifyLvCompare -PathType Leaf)) {
  throw "Missing $verifyLvCompare"
}

# Verify LabVIEW + LVCompare + LabVIEWCLI
$lvInfo = & pwsh -NoLogo -NoProfile -File $verifyLvCompare @(@{ Name='ProbeCli'; Value=$ProbeCli.IsPresent }) 2>$null
if (-not $lvInfo) { $lvInfo = [pscustomobject]@{} }

# Resolve VIPM path
$vendorTools = Join-Path $repoRoot 'src/tools/VendorTools.psm1'
Import-Module $vendorTools -Force
$vipmPath = Resolve-VIPMPath

function Get-FileVersion {
  param([string]$Path)
  try {
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    $info = Get-Item -LiteralPath $Path -ErrorAction Stop
    return $info.VersionInfo.FileVersion
  } catch { return $null }
}

$snapshot = [ordered]@{
  TimestampUtc   = (Get-Date).ToUniversalTime().ToString('o')
  Host           = $env:COMPUTERNAME
  OSVersion      = [System.Environment]::OSVersion.VersionString
  PowerShell     = $PSVersionTable.PSVersion.ToString()
  RepoRoot       = $repoRoot
  LabVIEWExePath = $lvInfo.LabVIEWExePath
  LVComparePath  = $lvInfo.LVComparePath
  LabVIEWCLIPath = $lvInfo.LabVIEWCLIPath
  ConfigSource   = $lvInfo.ConfigSource
  VIPMPath       = $vipmPath
  Versions       = [ordered]@{
    LabVIEWExe  = (Get-FileVersion $lvInfo.LabVIEWExePath)
    LVCompare   = (Get-FileVersion $lvInfo.LVComparePath)
    LabVIEWCLI  = (Get-FileVersion $lvInfo.LabVIEWCLIPath)
    VIPM        = (Get-FileVersion $vipmPath)
  }
}

$outRootAbs = Join-Path $repoRoot $OutputRoot
$timestamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$runDir     = Join-Path $outRootAbs $timestamp
New-Item -ItemType Directory -Path $runDir -Force | Out-Null
$jsonPath = Join-Path $runDir 'lv-env.snapshot.json'
$snapshot | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

Write-Host ("[verify-lv-env] Snapshot written: {0}" -f $jsonPath) -ForegroundColor Green
return $snapshot

