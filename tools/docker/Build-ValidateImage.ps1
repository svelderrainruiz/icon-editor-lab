#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
param(
  [Parameter()][ValidateSet('2021','2023','2025')][string]$LabVIEWVersion = '2023',
  [Parameter()][ValidateSet(32,64)][int]$Bitness = 64,
  [Parameter()][ValidateNotNullOrEmpty()][string]$Workspace = (Get-Location).Path,
  [Parameter()][int]$TimeoutSec = 600
)
param(
  [string]$ImageName = 'compare-validate',
  [string]$Dockerfile = (Join-Path $PSScriptRoot '../../docker/validate/Dockerfile')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Tool {
  param([string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required tool not found: $Name"
  }
}

Assert-Tool docker

$context = Split-Path -Path $Dockerfile -Parent
if (-not (Test-Path -LiteralPath $Dockerfile)) {
  throw "Dockerfile not found at $Dockerfile"
}

Write-Host ("[docker] Building {0} from {1}" -f $ImageName, $Dockerfile)
docker build -f $Dockerfile -t $ImageName $context

if ($LASTEXITCODE -ne 0) {
  throw "Docker build failed (exit=$LASTEXITCODE)"
}

Write-Host ("[docker] Image '{0}' built successfully." -f $ImageName)

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