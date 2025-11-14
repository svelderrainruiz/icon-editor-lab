#Requires -Version 7.0
[CmdletBinding()]
param(
  [string]$ConfigPath = 'local-ci/windows/profile.psd1',
  [string[]]$OnlyStages = @('25'),
  [ValidateSet('Toggle','Enable','Disable')][string]$Action = 'Toggle'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path '.').Path
$runner = Join-Path $repoRoot 'local-ci' 'windows' 'Invoke-LocalCI.ps1'
if (-not (Test-Path -LiteralPath $runner -PathType Leaf)) {
  throw "Local CI runner not found at $runner"
}

function Get-DevModeCurrentState {
  $modulePath = Join-Path $repoRoot 'src' 'tools' 'icon-editor' 'IconEditorDevMode.psm1'
  if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) { return $null }
  try {
    Import-Module $modulePath -Force -ErrorAction Stop
    return (Get-IconEditorDevModeState -RepoRoot $repoRoot)
  } catch { return $null }
}

function New-DebugConfigOverlay {
  param(
    [Parameter(Mandatory)][string]$BaseConfigPath,
    [Parameter(Mandatory)][ValidateSet('Enable','Disable')][string]$DevModeAction
  )
  $source = Get-Content -LiteralPath $BaseConfigPath -Raw -Encoding UTF8
  # Replace DevModeAction value only; keep spacing and comments
  $updated = [System.Text.RegularExpressions.Regex]::Replace(
    $source,
    "(?im)^\s*DevModeAction\s*=\s*'[^']*'",
    "DevModeAction           = '$DevModeAction'"
  )
  $tmpDir = Join-Path $env:TEMP 'icon-editor-lab'
  if (-not (Test-Path -LiteralPath $tmpDir -PathType Container)) { [void](New-Item -ItemType Directory -Path $tmpDir -Force) }
  $dest = Join-Path $tmpDir ("profile.debug.{0}.psd1" -f ([Guid]::NewGuid().ToString('N')))
  $updated | Set-Content -LiteralPath $dest -Encoding UTF8
  return $dest
}

$env:LOCALCI_DEBUG_DEV_MODE = '1'
Write-Host "[Run-DevMode-Debug] LOCALCI_DEBUG_DEV_MODE=1" -ForegroundColor Cyan

# Decide desired action
if ($Action -eq 'Toggle') {
  # Toggle DevModeAction based on current state
  $state = Get-DevModeCurrentState
  $isActive = $false
  if ($state -and $state.PSObject.Properties['Active']) { $isActive = [bool]$state.Active }
  $nextAction = if ($isActive) { 'Disable' } else { 'Enable' }
} else {
  $nextAction = $Action
}
Write-Host ("==> Stage 25 - DevMode ({0})" -f $nextAction) -ForegroundColor Cyan

$overlayPath = New-DebugConfigOverlay -BaseConfigPath $ConfigPath -DevModeAction $nextAction

& pwsh -NoLogo -NoProfile -File $runner -ConfigPath $overlayPath -OnlyStages $OnlyStages
