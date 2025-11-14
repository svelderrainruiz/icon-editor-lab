#Requires -Version 7.0
[CmdletBinding()]param(
  [string]$RelativePath = 'src',
  [string]$VipcPath,
  [string]$MinimumSupportedLVVersion = '2021',
  [string]$VIP_LVVersion = '2023',
  [string[]]$SupportedBitness = @('64'),
  [switch]$DisplayOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..')).ProviderPath
$scriptPath = Join-Path $repoRoot 'src/tools/icon-editor/Invoke-VipmDependencies.ps1'
if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
  throw "Invoke-VipmDependencies.ps1 not found at '$scriptPath'"
}

# Helpful hint if VIPM is not running
function Test-VipmRunning {
  $procs = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'vipm|package.*manager' })
  if ($procs.Count -gt 0) { return $true }
  try {
    $procs = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'vipm|package.*manager' })
    return ($procs.Count -gt 0)
  } catch { return $false }
}

if (-not (Test-VipmRunning)) {
  Write-Warning 'VIPM does not appear to be running. Please start VIPM before applying dependencies (DisplayOnly can run without it).'
}

$args = @()
if ($VipcPath) { $args += @('-VIPCPath', $VipcPath) }
$args += @(
  '-RelativePath', $RelativePath,
  '-MinimumSupportedLVVersion', $MinimumSupportedLVVersion,
  '-VIP_LVVersion', $VIP_LVVersion,
  '-SupportedBitness', ($SupportedBitness -join ',' )
)
if ($DisplayOnly) { $args += '-DisplayOnly' }

Write-Host ('[repair-lv-env] pwsh -File {0} {1}' -f $scriptPath, ($args -join ' ')) -ForegroundColor Cyan
& pwsh -NoLogo -NoProfile -File $scriptPath @args

