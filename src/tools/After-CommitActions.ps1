#Requires -Version 7.0
[CmdletBinding()]
param(
  [string]$RepositoryRoot = '.',
  [switch]$Push,
  [switch]$CreatePR
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Invoke-Git: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Invoke-Git {

    # ShouldProcess guard: honor -WhatIf / -Confirm
    if (-not $PSCmdlet.ShouldProcess($MyInvocation.MyCommand.Name, 'Execute')) { return }
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param(
    [Parameter(Mandatory)] [string[]]$Args,
    [string]$WorkDir = $RepositoryRoot
  )
  Push-Location $WorkDir
  try {
    $out = & git @Args 2>&1
    [pscustomobject]@{ Code=$LASTEXITCODE; Out=$out }
  } finally { Pop-Location }
}

<#
.SYNOPSIS
Ensure-AgentDirs: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Ensure-AgentDirs {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param([string]$Root)
  $dir = Join-Path $Root 'tests/results/_agent'
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  return $dir
}

<#
.SYNOPSIS
Ensure-Gh: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Ensure-Gh {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { return $false }
  return $true
}

$root = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$agentDir = Ensure-AgentDirs -Root $root
$postPath = Join-Path $agentDir 'post-commit.json'

$branch = (Invoke-Git -Args @('rev-parse','--abbrev-ref','HEAD')).Out | Select-Object -First 1
$remote = 'origin'

$result = [ordered]@{
  schema = 'post-commit/actions@v1'
  generatedAt = (Get-Date).ToString('o')
  repoRoot = $root
  branch = $branch
  pushExecuted = $false
  pushResult = $null
  createPR = [bool]$CreatePR
  prResult = $null
}

if ($Push) {
  $pushRes = Invoke-Git -Args @('push','-u',$remote,$branch)
  $result.pushExecuted = $true
  $result.pushResult = [ordered]@{ ExitCode=$pushRes.Code; Output=@($pushRes.Out) }
}

if ($CreatePR) {
  if (Ensure-Gh) {
    $prArgs = @('pr','create','--fill','--base','develop')
    $prOut = & gh @prArgs 2>&1
    $result.prResult = [ordered]@{ created=($LASTEXITCODE -eq 0); output=@($prOut) }
  } else {
    $result.prResult = [ordered]@{ created=$false; output=@('gh CLI not available') }
  }
}

$result | ConvertTo-Json -Depth 8 | Out-File -LiteralPath $postPath -Encoding utf8
Write-Host ("After-CommitActions: summary written to {0}" -f $postPath)


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