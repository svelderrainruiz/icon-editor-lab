<#
.SYNOPSIS
  Emit a small interactivity/console probe to the job Step Summary and stdout.
#>
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Line([string]$s){ $s | Out-Host }

$data = [ordered]@{}
$data.schema = 'interactivity-probe/v1'
$data.timestamp = (Get-Date).ToUniversalTime().ToString('o')
$data.os = [System.Environment]::OSVersion.VersionString
$data.userInteractive = [bool][System.Environment]::UserInteractive
$p = [System.Diagnostics.Process]::GetCurrentProcess()
$data.sessionId = $p.SessionId

try { $data.isInputRedirected  = [Console]::IsInputRedirected }  catch { $data.isInputRedirected  = $null }
try { $data.isOutputRedirected = [Console]::IsOutputRedirected } catch { $data.isOutputRedirected = $null }
try { $data.isErrorRedirected  = [Console]::IsErrorRedirected }  catch { $data.isErrorRedirected  = $null }

$likelyInteractive = $false
if ($data.userInteractive -and -not $data.isInputRedirected) { $likelyInteractive = $true }
$data.likelyInteractive = $likelyInteractive

$json = $data | ConvertTo-Json -Depth 4
Write-Line $json

if ($env:GITHUB_STEP_SUMMARY) {
  $lines = @('### Interactivity Probe','')
  $lines += ('- OS: {0}' -f $data.os)
  $lines += ('- SessionId: {0}' -f $data.sessionId)
  $lines += ('- UserInteractive: {0}' -f $data.userInteractive)
  $lines += ('- In/Out/Err redirected: {0}/{1}/{2}' -f $data.isInputRedirected,$data.isOutputRedirected,$data.isErrorRedirected)
  $lines += ('- LikelyInteractive: {0}' -f $data.likelyInteractive)
  $lines -join "`n" | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
}


<#
.SYNOPSIS
Test-ValidLabel: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Test-ValidLabel {

    # ShouldProcess guard: honor -WhatIf / -Confirm
    if (-not $PSCmdlet.ShouldProcess($MyInvocation.MyCommand.Name, 'Execute')) { return }
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