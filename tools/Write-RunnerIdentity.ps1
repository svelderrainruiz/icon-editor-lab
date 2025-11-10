<#
.SYNOPSIS
  Append runner identity metadata to job summary.
#>
[CmdletBinding()]
param(
  [string]$SampleId
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
  if (-not $env:GITHUB_STEP_SUMMARY) { exit 0 }

  function Get-Env($n){
    try { $v = [System.Environment]::GetEnvironmentVariable($n) } catch { $v = $null }
    if ($null -ne $v) { return "$v" } else { return '' }
  }

  $name = Get-Env 'RUNNER_NAME'
  $os   = Get-Env 'RUNNER_OS'
  $arch = Get-Env 'RUNNER_ARCH'
  $repo = Get-Env 'GITHUB_REPOSITORY'
  $run  = Get-Env 'GITHUB_RUN_ID'
  $ref  = Get-Env 'GITHUB_REF_NAME'

  $lines = @('### Runner','')
  if ($name) { $lines += ('- Name: {0}' -f $name) }
  if ($os -or $arch) { $lines += ('- OS/Arch: {0}/{1}' -f $os,$arch) }
  if ($repo) { $lines += ('- Repo: {0}' -f $repo) }
  if ($ref) { $lines += ('- Branch: {0}' -f $ref) }
  if ($run) { $lines += ('- Run: {0}' -f $run) }
  if ($SampleId) { $lines += ('- sample_id: {0}' -f $SampleId) }

  $lines -join "`n" | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8 -ErrorAction SilentlyContinue
  exit 0
} catch {
  Write-Host "::notice::Write-RunnerIdentity failed: $_"
  exit 0
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