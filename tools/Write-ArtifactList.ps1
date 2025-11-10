<#
.SYNOPSIS
  Append a compact artifact path list to the job summary.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string[]]$Paths,
  [string]$Title = 'Artifacts'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $env:GITHUB_STEP_SUMMARY) { return }

$lines = @("### $Title",'')
$any = $false
foreach ($p in $Paths) {
  if (-not [string]::IsNullOrWhiteSpace($p) -and (Test-Path -LiteralPath $p)) { $lines += ('- ' + $p); $any = $true }
}
if (-not $any) { $lines += '- (none found)' }
$lines -join "`n" | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8


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