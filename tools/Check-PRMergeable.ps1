Set-StrictMode -Version Latest
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
param(
  [Parameter()][ValidateSet('2021','2023','2025')][string]$LabVIEWVersion = '2023',
  [Parameter()][ValidateSet(32,64)][int]$Bitness = 64,
  [Parameter()][ValidateNotNullOrEmpty()][string]$Workspace = (Get-Location).Path,
  [Parameter()][int]$TimeoutSec = 600
)
$ErrorActionPreference = 'Stop'
$PSModuleAutoLoadingPreference = 'None'
#Requires -Version 7.0
<#
.SYNOPSIS
  Check a pull request mergeability state via the GitHub API.
.DESCRIPTION
  Calls the GitHub REST API to retrieve merge status for the specified pull request
  (using GH_TOKEN / GITHUB_TOKEN). Retries while the mergeable state is unknown,
  so it can be invoked immediately after PR creation.
.PARAMETER Repo
  Git repository in OWNER/REPO form. Defaults to $env:GITHUB_REPOSITORY.
.PARAMETER Number
  Pull request number to inspect (required).
.PARAMETER Retries
  How many times to poll when the mergeable state is "unknown" (default: 6).
.PARAMETER DelaySeconds
  Seconds between retries when state is unknown (default: 5).
.PARAMETER FailOnConflict
  When set, exit with code 1 if the mergeable state is "dirty" (merge conflicts).
.EXAMPLE
  pwsh -File tools/Check-PRMergeable.ps1 -Number 274 -FailOnConflict
#>
param(
  [string]$Repo = $env:GITHUB_REPOSITORY,
  [Parameter(Mandatory = $true)]
  [int]$Number,
  [int]$Retries = 6,
  [int]$DelaySeconds = 5,
  [switch]$FailOnConflict
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $Repo) {
  throw "Repo not provided and GITHUB_REPOSITORY is empty. Supply -Repo OWNER/REPO."
}

$token = $env:GH_TOKEN
if (-not $token) { $token = $env:GITHUB_TOKEN }
if (-not $token) {
  throw "GH_TOKEN or GITHUB_TOKEN is required to query the pull request."
}

$uri = "https://api.github.com/repos/$Repo/pulls/$Number"

<#
.SYNOPSIS
Get-MergeableState: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Get-MergeableState {

    # ShouldProcess guard: honor -WhatIf / -Confirm
    if (-not $PSCmdlet.ShouldProcess($MyInvocation.MyCommand.Name, 'Execute')) { return }
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param([string]$RequestUri, [string]$Token)

  $headers = @{
    Authorization = "Bearer $Token"
    Accept        = "application/vnd.github+json"
    'User-Agent'  = 'compare-vi-cli-action/mergeable-check'
  }

  $response = Invoke-RestMethod -Method Get -Uri $RequestUri -Headers $headers
  return [pscustomobject]@{
    mergeable      = $response.mergeable
    mergeableState = $response.mergeable_state
    updatedAt      = $response.updated_at
    baseRef        = $response.base.ref
    headRef        = $response.head.ref
  }
}

$attempt = 0
$result = $null
do {
  $attempt++
  $result = Get-MergeableState -RequestUri $uri -Token $token

  Write-Host ("[mergeable] Attempt {0}: state={1}, mergeable={2}" -f $attempt, $result.mergeableState, $result.mergeable)

  if ($result.mergeableState -eq 'unknown' -and $attempt -lt ($Retries + 1)) {
    Start-Sleep -Seconds ([Math]::Max(1, $DelaySeconds))
  } else {
    break
  }
} while ($true)

$output = [pscustomobject]@{
  repo           = $Repo
  number         = $Number
  mergeable      = $result.mergeable
  mergeableState = $result.mergeableState
  updatedAt      = $result.updatedAt
  baseRef        = $result.baseRef
  headRef        = $result.headRef
  attempts       = $attempt
}

$output | ConvertTo-Json -Depth 3 | Write-Host

if ($FailOnConflict -and ($result.mergeableState -eq 'dirty' -or $result.mergeable -eq $false)) {
  Write-Error "Pull request #$Number has merge conflicts (state=$($result.mergeableState))."
  exit 1
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