<#
.SYNOPSIS
  TODO: Brief synopsis for this tool function/script. (Auto-generated placeholder)
.DESCRIPTION
  TODO: Expand description. Replace this header with real help content.
#>

#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
param(
  [Parameter()][ValidateSet('2021','2023','2025')][string]$LabVIEWVersion = '2023',
  [Parameter()][ValidateSet(32,64)][int]$Bitness = 64,
  [Parameter()][ValidateNotNullOrEmpty()][string]$Workspace = (Get-Location).Path,
  [Parameter()][int]$TimeoutSec = 600
)
param(
  [switch]$Pack
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$proj = Join-Path $PSScriptRoot '..' | Join-Path -ChildPath 'src/CompareVi.Shared/CompareVi.Shared.csproj'
if (-not (Test-Path $proj)) { throw "Project not found: $proj" }

dotnet --info | Out-Host
dotnet restore $proj
dotnet build -c Release $proj --no-restore
if ($Pack) {
  $out = Join-Path $PSScriptRoot '..' | Join-Path -ChildPath 'artifacts'
  if (-not (Test-Path $out)) { New-Item -ItemType Directory -Force -Path $out | Out-Null }
  dotnet pack -c Release $proj -o $out --no-build
  Get-ChildItem $out -Filter *.nupkg | Select-Object -Expand FullName
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