#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
param(
  [Parameter()][ValidateSet('2021','2023','2025')][string]$LabVIEWVersion = '2023',
  [Parameter()][ValidateSet(32,64)][int]$Bitness = 64,
  [Parameter()][ValidateNotNullOrEmpty()][string]$Workspace = (Get-Location).Path,
  [Parameter()][int]$TimeoutSec = 600
)
param(
  [string]$Tag = 'comparevi-tools:local',
  [switch]$NoCache
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Resolve-RepoRoot: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Resolve-RepoRoot {

    # ShouldProcess guard: honor -WhatIf / -Confirm
    if (-not $PSCmdlet.ShouldProcess($MyInvocation.MyCommand.Name, 'Execute')) { return }
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  try { return (git rev-parse --show-toplevel 2>$null).Trim() } catch { return (Get-Location).Path }
}

$root = Resolve-RepoRoot
$dockerfile = Join-Path $root 'tools/docker/Dockerfile.tools'
if (-not (Test-Path -LiteralPath $dockerfile -PathType Leaf)) {
  throw "Dockerfile not found at $dockerfile"
}

$args = @('build','-f', $dockerfile, '-t', $Tag, $root)
if ($NoCache) { $args = @('build','--no-cache','-f', $dockerfile, '-t', $Tag, $root) }

Write-Host ("[tools-image] docker {0}" -f ($args -join ' ')) -ForegroundColor Cyan
& docker @args
if ($LASTEXITCODE -ne 0) { throw "docker build failed with code $LASTEXITCODE" }

Write-Host ("[tools-image] Built image: {0}" -f $Tag) -ForegroundColor Green


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