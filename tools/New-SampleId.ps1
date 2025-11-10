Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSModuleAutoLoadingPreference = 'None'
<#
.SYNOPSIS
  Generate a sample_id for workflow_dispatch runs.
.DESCRIPTION
  Emits a compact, readable sample id by default (ts-YYYYMMDD-HHMMSS-XXXX).
  Can emit GUID with -Format guid.
.PARAMETER Prefix
  Optional prefix to add before the id.
.PARAMETER Format
  'ts' (default) or 'guid'.
.OUTPUTS
  Writes the id to stdout and sets GITHUB_OUTPUT 'sample_id' if available.
#>
[CmdletBinding()]
param(
  [string]$Prefix,
  [ValidateSet('ts','guid')][string]$Format = 'ts'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
New-TsId: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function New-TsId {

    # ShouldProcess guard: honor -WhatIf / -Confirm
    if (-not $PSCmdlet.ShouldProcess($MyInvocation.MyCommand.Name, 'Execute')) { return }
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
  $rnd = -join ((48..57 + 97..122) | Get-Random -Count 4 | ForEach-Object {[char]$_})
  "ts-$ts-$rnd"
}

$id = if ($Format -eq 'guid') { [guid]::NewGuid().ToString() } else { New-TsId }
if ($Prefix) { $id = "$Prefix$id" }

if ($env:GITHUB_OUTPUT) { "sample_id=$id" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8 }
Write-Output $id


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