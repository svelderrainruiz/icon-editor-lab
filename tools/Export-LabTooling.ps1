<#
.SYNOPSIS
  TODO: Brief synopsis for this tool function/script. (Auto-generated placeholder)
.DESCRIPTION
  TODO: Expand description. Replace this header with real help content.
#>

#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSModuleAutoLoadingPreference = 'None'
[CmdletBinding()]
param(
  [string]$Destination = 'artifacts/icon-editor-lab-tooling.zip',
  [string[]]$IncludePaths = @(
    'tools',
    'configs',
    'vendor',
    'docs/LVCOMPARE_LAB_PLAN.md',
    'docs/ICON_EDITOR_PACKAGE.md',
    'docs/LABVIEW_GATING.md',
    'docs/TROUBLESHOOTING.md'
  ),
  [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$destinationPath = if ([System.IO.Path]::IsPathRooted($Destination)) {
  $Destination
} else {
  Join-Path $repoRoot $Destination
}
$destinationDir = Split-Path -Parent $destinationPath
if (-not (Test-Path -LiteralPath $destinationDir -PathType Container)) {
  New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
}
if ((Test-Path -LiteralPath $destinationPath -PathType Leaf) -and -not $Force) {
  throw "Destination '$destinationPath' already exists. Use -Force to overwrite."
}

$staging = Join-Path ([System.IO.Path]::GetTempPath()) ("icon-editor-lab-{0}" -f ([guid]::NewGuid().ToString('n')))
New-Item -ItemType Directory -Path $staging -Force | Out-Null

try {
  foreach ($path in $IncludePaths) {
    if (-not $path) { continue }
    $source = Join-Path $repoRoot $path
    if (-not (Test-Path -LiteralPath $source)) {
      Write-Warning ("Skipping missing path '{0}'." -f $path)
      continue
    }
    if ((Get-Item -LiteralPath $source).PSIsContainer) {
      Copy-Item -Path $source -Destination (Join-Path $staging (Split-Path -Leaf $path)) -Recurse -Force
    } else {
      $targetDir = Join-Path $staging (Split-Path -Parent $path)
      if ($targetDir -and -not (Test-Path -LiteralPath $targetDir -PathType Container)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
      }
      Copy-Item -Path $source -Destination (Join-Path $staging $path) -Force
    }
  }

  if (Test-Path -LiteralPath $destinationPath) {
    Remove-Item -LiteralPath $destinationPath -Force
  }
  Compress-Archive -Path (Join-Path $staging '*') -DestinationPath $destinationPath -Force
  Write-Host ("Exported lab tooling to {0}" -f $destinationPath)
} finally {
  Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
}

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