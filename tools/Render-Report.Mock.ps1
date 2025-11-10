<#
.SYNOPSIS
  TODO: Brief synopsis for this tool function/script. (Auto-generated placeholder)
.DESCRIPTION
  TODO: Expand description. Replace this header with real help content.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSModuleAutoLoadingPreference = 'None'
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$renderer = Join-Path $root 'scripts' 'Render-CompareReport.ps1'

& $renderer `
  -Command '"C:\Program Files\National Instruments\Shared\LabVIEW Compare\LVCompare.exe" "C:\\VIs\\a.vi" "C:\\VIs\\b.vi" --log "C:\\Temp\\Spaced Path\\x"' `
  -ExitCode 1 `
  -Diff 'true' `
  -CliPath 'C:\Program Files\National Instruments\Shared\LabVIEW Compare\LVCompare.exe' `
  -OutputPath (Join-Path $root 'tests' 'results' 'compare-report.mock.html')

Write-Host 'Mock HTML report generated.'

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