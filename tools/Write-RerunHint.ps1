<#
.SYNOPSIS
  Append a concise re-run hint block using gh workflow run with sample_id.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$Workflow,
  [string]$IncludeIntegration,
  [string]$SampleId
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $env:GITHUB_STEP_SUMMARY) { return }

if (-not $SampleId) { $SampleId = [guid]::NewGuid().ToString() }
$repo = $env:GITHUB_REPOSITORY
$ref  = if ($env:GITHUB_REF_NAME) { $env:GITHUB_REF_NAME } else { 'develop' }

$args = @()
if ($IncludeIntegration -and $IncludeIntegration -ne '') { $args += ('-f include_integration={0}' -f $IncludeIntegration) }
$args += ('-f sample_id={0}' -f $SampleId)
$cmd = "gh workflow run $Workflow -R $repo -r $ref {0}" -f ($args -join ' ')

$lines = @('### Re-run (gh)','')
$lines += ('```bash')
$lines += ($cmd)
$lines += ('```')
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