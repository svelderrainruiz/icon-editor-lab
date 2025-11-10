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
  [string]$Workflow = '.github/workflows/ci-orchestrated.yml',
  [string]$Branch,
  [switch]$Watch,
  [int]$Limit = 15
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-GhJson {
  param([string[]]$Args)
  $gh = Get-Command gh -ErrorAction Stop
  $raw = & $gh.Source @Args
  if ($LASTEXITCODE -ne 0) { throw "gh exited with code $LASTEXITCODE" }
  if (-not $raw) { return $null }
  return ($raw | ConvertFrom-Json)
}

function Get-CurrentBranch {
  if ($Branch) { return $Branch }
  try { return (& git rev-parse --abbrev-ref HEAD).Trim() } catch { return $null }
}

function Get-LatestRunForBranch {
  param([string]$Workflow,[string]$Branch,[int]$Limit)
  $runs = Invoke-GhJson -Args @('run','list','--workflow', $Workflow, '--json','databaseId,displayTitle,headBranch,status,conclusion,url,headSha,createdAt','--limit',[string]$Limit)
  if (-not $runs) { return $null }
  $match = $runs | Where-Object { $_.headBranch -eq $Branch } | Sort-Object databaseId -Descending | Select-Object -First 1
  return $match
}

$branch = Get-CurrentBranch
if (-not $branch) { throw 'Unable to determine branch; pass -Branch explicitly.' }

$run = Get-LatestRunForBranch -Workflow $Workflow -Branch $branch -Limit $Limit
if (-not $run) { throw "No runs found for branch '$branch' (workflow '$Workflow')." }

Write-Host ("Run: {0}" -f $run.displayTitle)
Write-Host ("Branch: {0}  SHA: {1}" -f $run.headBranch, $run.headSha)
Write-Host ("Status: {0}  Conclusion: {1}" -f ($run.status ?? 'n/a'), ($run.conclusion ?? ''))
Write-Host ("URL: {0}" -f $run.url)

$jobObj = Invoke-GhJson -Args @('run','view', [string]$run.databaseId, '--json','jobs')
if ($jobObj -and $jobObj.jobs) {
  Write-Host ''
  Write-Host 'Jobs:'
  foreach ($j in $jobObj.jobs) {
    $s = if ($j.status) { $j.status } else { '' }
    $c = if ($j.conclusion) { $j.conclusion } else { '' }
    Write-Host ("- {0}  [{1}/{2}]  {3}" -f $j.name, $s, $c, $j.url)
  }
}

if ($Watch) {
  Write-Host ''
  Write-Host 'Watching run logs (Ctrl+C to stop)...'
  $gh = Get-Command gh -ErrorAction Stop
  $watchArgs = @('run','watch',[string]$run.databaseId,'--exit-status')
  $watchLines = @()
  & $gh.Source @watchArgs 2>&1 | Tee-Object -Variable watchLines
  $exitCode = $LASTEXITCODE
  if ($exitCode -ne 0) {
    $combined = ($watchLines | Out-String).Trim()
    if ($combined -match '401\s+Unauthorized') {
      Write-Warning 'gh run watch returned 401 Unauthorized. Provide GH_TOKEN/GITHUB_TOKEN with repo scope or run `gh auth login` to stream run logs.'
    } elseif ($combined -match 'exceeded retry limit') {
      Write-Warning 'gh run watch encountered repeated stream errors. Confirm your GitHub authentication and network access.'
    }
    if ($combined) {
      Write-Warning $combined
    }
    throw "gh run watch exited with code $exitCode"
  }
}


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