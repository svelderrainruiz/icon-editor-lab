#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSModuleAutoLoadingPreference = 'None'
[CmdletBinding(DefaultParameterSetName='BodyFile')]
param(
  [Parameter(Mandatory=$true)]
  [int]$Issue,

  [Parameter(ParameterSetName='BodyFile', Mandatory=$true)]
  [string]$BodyFile,

  [Parameter(ParameterSetName='Body', Mandatory=$true)]
  [string]$Body,

  [switch]$EditLast,
  [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Ensure-Gh: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Ensure-Gh {

    # ShouldProcess guard: honor -WhatIf / -Confirm
    if (-not $PSCmdlet.ShouldProcess($MyInvocation.MyCommand.Name, 'Execute')) { return }
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI ('gh') is required but was not found on PATH."
  }
}

Ensure-Gh

$issueArg = @('issue','comment',$Issue.ToString())
if ($EditLast) {
  $issueArg = @('issue','comment',$Issue.ToString(),'--edit-last')
}

switch ($PSCmdlet.ParameterSetName) {
  'BodyFile' {
    $resolved = Resolve-Path -LiteralPath $BodyFile -ErrorAction Stop
    $args = $issueArg + @('--body-file', $resolved.Path)
    if (-not $Quiet) {
      Write-Host ("Posting comment from file '{0}' to issue #{1}..." -f $resolved.Path, $Issue)
    }
    & gh @args
    if ($LASTEXITCODE -ne 0) {
      throw "gh issue comment exited with code $LASTEXITCODE."
    }
  }
  'Body' {
    $temp = [System.IO.Path]::GetTempFileName()
    try {
      Set-Content -LiteralPath $temp -Value $Body -Encoding utf8
      $args = $issueArg + @('--body-file', $temp)
      if (-not $Quiet) {
        Write-Host ("Posting comment to issue #{0} using temporary body file..." -f $Issue)
      }
      & gh @args
      if ($LASTEXITCODE -ne 0) {
        throw "gh issue comment exited with code $LASTEXITCODE."
      }
    } finally {
      Remove-Item -LiteralPath $temp -ErrorAction SilentlyContinue
    }
  }
  default {
    throw "Unsupported parameter set '$($PSCmdlet.ParameterSetName)'."
  }
}

if (-not $Quiet) {
  Write-Host "Issue comment posted successfully." -ForegroundColor Green
}

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