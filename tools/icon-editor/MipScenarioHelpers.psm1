#Requires -Version 7.0

Set-StrictMode -Version Latest

function Resolve-Abs {
  param(
    [string]$PathCandidate,
    [string]$BasePath = $(Get-Location).Path
  )
  if ([string]::IsNullOrWhiteSpace($PathCandidate)) { return $null }
  if ([System.IO.Path]::IsPathRooted($PathCandidate)) {
    return (Resolve-Path -LiteralPath $PathCandidate -ErrorAction Stop).ProviderPath
  }
  return (Resolve-Path -LiteralPath (Join-Path $BasePath $PathCandidate) -ErrorAction Stop).ProviderPath
}

function Test-VIAnalyzerToolkit {
  param(
    [int]$Version,
    [int]$Bitness
  )
  $result = [ordered]@{ exists = $false; reason = $null; toolkitPath = $null; labviewExe = $null }
  try {
    $lvExe = Find-LabVIEWVersionExePath -Version $Version -Bitness $Bitness -ErrorAction Stop
    $result.labviewExe = $lvExe
  } catch {
    $result.reason = "Unable to resolve LabVIEW $Version ($Bitness-bit). Ensure it is installed."
    return $result
  }
  $lvRoot = Split-Path -Parent $lvExe
  $addonsRoot = Join-Path $lvRoot 'vi.lib' 'addons'
  $candidateNames = @('NI_VIAnalyzer','NI VI Analyzer','VIAnalyzer','VI Analyzer','analyzer')
  $resolvedToolkit = $null
  foreach ($name in $candidateNames) {
    $candidatePath = Join-Path $addonsRoot $name
    if (-not (Test-Path -LiteralPath $candidatePath -PathType Container)) { continue }
    $marker = Join-Path $candidatePath 'NI_VIAnalyzerTKVIs.lvlib'
    if ((Test-Path -LiteralPath $marker -PathType Leaf) -or $name -eq 'analyzer') {
      $resolvedToolkit = (Resolve-Path -LiteralPath $candidatePath).ProviderPath
      break
    }
  }
  if (-not $resolvedToolkit) {
    $result.reason = ("VI Analyzer Toolkit directory not found under '{0}'. Checked: {1}" -f $addonsRoot, ($candidateNames -join ', '))
    return $result
  }
  $result.exists = $true
  $result.toolkitPath = $resolvedToolkit
  return $result
}

function Test-GCliAvailable {
  $result = [ordered]@{ available = $false; version = $null; reason = $null }
  $cmd = Get-Command g-cli -ErrorAction SilentlyContinue
  if (-not $cmd) {
    $result.reason = 'g-cli not found on PATH.'
    return $result
  }
  try {
    $versionOutput = & g-cli --version 2>&1
    $result.available = $true
    if ($versionOutput) { $result.version = ($versionOutput | Select-Object -First 1).Trim() }
  } catch {
    $result.reason = "g-cli --version failed: $($_.Exception.Message)"
  }
  return $result
}

function Get-LabVIEWServerInfo {
  param([string]$LabVIEWExePath)
  $info = [ordered]@{ iniPath = $null; enabled = $null; port = $null; warnings = @() }
  try {
    $iniPath = Get-LabVIEWIniPath -LabVIEWExePath $LabVIEWExePath -ErrorAction Stop
    $info.iniPath = $iniPath
    $enabled = Get-LabVIEWIniValue -LabVIEWExePath $LabVIEWExePath -LabVIEWIniPath $iniPath -Key 'server.tcp.enabled'
    if ($enabled -and $enabled.Trim().ToLowerInvariant() -in @('1','true')) {
      $info.enabled = $true
    } else {
      $info.enabled = $false
      $info.warnings += "LabVIEW VI Server disabled in $iniPath (server.tcp.enabled=$enabled)."
    }
    $portValue = Get-LabVIEWIniValue -LabVIEWExePath $LabVIEWExePath -LabVIEWIniPath $iniPath -Key 'server.tcp.port'
    if ($portValue) { $info.port = $portValue.Trim() }
  } catch {
    $info.warnings += $_.Exception.Message
  }
  return $info
}

function Get-ReportPathFromOutput {
  param([string[]]$Lines)
  if (-not $Lines) { return $null }
  $window = $Lines | Where-Object { $_ -match '\S' }
  if (-not $window) { return $null }
  for ($idx = $window.Count - 1; $idx -ge 0 -and $idx -ge $window.Count - 50; $idx--) {
    $line = $window[$idx]
    if ($line -match '(?i)Report\s+written\s+to:\s*(.+)$') {
      return $Matches[1].Trim()
    }
  }
  return $null
}

function Write-AnalyzerDevModeWarning {
  param(
    [string]$AnalyzerDir,
    [string]$Prefix = '[6b]',
    [switch]$PassThru
  )
  if (-not $AnalyzerDir) { return $false }
  $jsonPath = Join-Path $AnalyzerDir 'vi-analyzer.json'
  if (-not (Test-Path -LiteralPath $jsonPath -PathType Leaf)) { return $false }
  try {
    $data = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json
    if ($data.devModeLikelyDisabled) {
      $message = ("{0} Analyzer indicates MissingInProjectCLI.vi failed; development mode is likely disabled. Re-run tools/icon-editor/Enable-DevMode.ps1 for the appropriate LabVIEW version and retry." -f $Prefix)
      Write-Host $message -ForegroundColor Yellow
      if ($PassThru) { return $message }
      return $true
    }
  } catch {}
  return $false
}

Export-ModuleMember -Function Resolve-Abs, Test-VIAnalyzerToolkit, Test-GCliAvailable, Get-LabVIEWServerInfo, Get-ReportPathFromOutput, Write-AnalyzerDevModeWarning

function Test-ValidLabel {
  param([Parameter(Mandatory)][string]$Label)
  if ($Label -notmatch '^[A-Za-z0-9._-]{1,64}$') { throw "Invalid label: $Label" }
}

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