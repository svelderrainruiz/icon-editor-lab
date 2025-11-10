<#
.SYNOPSIS
  TODO: Brief synopsis for this tool function/script. (Auto-generated placeholder)
.DESCRIPTION
  TODO: Expand description. Replace this header with real help content.
#>

param(
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
param(
  [Parameter()][ValidateSet('2021','2023','2025')][string]$LabVIEWVersion = '2023',
  [Parameter()][ValidateSet(32,64)][int]$Bitness = 64,
  [Parameter()][ValidateNotNullOrEmpty()][string]$Workspace = (Get-Location).Path,
  [Parameter()][int]$TimeoutSec = 600
)
  [Parameter(Position=0)][Alias('Path')][string]$InputFile,
  [ValidateSet('Markdown','Text')][string]$Format = 'Markdown',
  [string]$OutFile,
  [switch]$AppendStepSummary,
  [string]$Title = 'Compare Loop Run Summary'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$modulePath = Join-Path (Split-Path -Parent $PSCommandPath) '..' 'module' 'RunSummary' 'RunSummary.psm1'
if (Test-Path -LiteralPath $modulePath) { Import-Module $modulePath -Force }
$resolved = $InputFile
if (-not $resolved -and $env:RUNSUMMARY_INPUT_FILE) { $resolved = $env:RUNSUMMARY_INPUT_FILE }
if (-not $resolved) { throw 'Input file not provided (argument or RUNSUMMARY_INPUT_FILE).' }
$content = Convert-RunSummary -InputFile $resolved -Format $Format -AsString -Title $Title -AppendStepSummary:$AppendStepSummary
if ($OutFile) { [IO.File]::WriteAllText($OutFile, $content, [Text.Encoding]::UTF8) }
Write-Host $content

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