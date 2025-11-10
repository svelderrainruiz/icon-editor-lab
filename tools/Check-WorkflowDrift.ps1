<#
.SYNOPSIS
  TODO: Brief synopsis for this tool function/script. (Auto-generated placeholder)
.DESCRIPTION
  TODO: Expand description. Replace this header with real help content.
#>


[CmdletBinding()]
param(
  [switch]$AutoFix,
  [switch]$Stage,
  [string]$CommitMessage
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$workflowFiles = @(
  '.github/workflows/pester-selfhosted.yml',
  '.github/workflows/fixture-drift.yml',
  '.github/workflows/ci-orchestrated.yml',
  '.github/workflows/pester-integration-on-label.yml',
  '.github/workflows/smoke.yml',
  '.github/workflows/compare-artifacts.yml'
)

function Resolve-PythonExe {
  $candidates = @('python','py')
  foreach ($name in $candidates) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
  }
  return $null
}

$py = Resolve-PythonExe
if (-not $py) {
  Write-Host '::notice::Python not found; skipping workflow drift check.'
  exit 0
}

& $py -m pip install --user ruamel.yaml > $null 2>&1

function Process-Staging {
  param([string[]]$ChangedFiles)

  if (-not ($Stage -or $CommitMessage)) { return }

  if (-not $ChangedFiles -or $ChangedFiles.Count -eq 0) {
    Write-Host '::notice::No workflow drift changes to stage or commit.'
    return
  }

  git add $ChangedFiles | Out-Null
  Write-Host ('Staged workflow drift changes: {0}' -f ($ChangedFiles -join ', '))

  if (-not $CommitMessage) { return }

  $staged = git diff --cached --name-only | Where-Object { $_ }
  $extra = @($staged | Where-Object { $ChangedFiles -notcontains $_ })
  if ($extra.Count -gt 0) {
    Write-Host ('::warning::Additional files already staged (skipping auto-commit): {0}' -f ($extra -join ', '))
    return
  }

  try {
    git commit -m $CommitMessage | Out-Host
  } catch {
    Write-Host "::notice::Commit failed or nothing to commit: $_"
  }
}

if ($AutoFix) {
  & $py tools/workflows/update_workflows.py --write @workflowFiles | Out-Host
}

& $py tools/workflows/update_workflows.py --check @workflowFiles | Out-Host
$exitCode = $LASTEXITCODE

switch ($exitCode) {
  0 {
    Write-Host 'Workflow drift check passed.'
    $changed = @()
    foreach ($wf in $workflowFiles) {
      if (git status --porcelain $wf) { $changed += $wf }
    }
    if ($changed.Count -gt 0) {
      git --no-pager diff --stat @changed | Out-Host
      git --no-pager diff @changed | Out-Host
    }
    Process-Staging -ChangedFiles $changed
    exit 0
  }
  3 {
    Write-Warning 'Workflow drift detected (auto-fix applied).'
    $changed = @()
    foreach ($wf in $workflowFiles) {
      if (git status --porcelain $wf) { $changed += $wf }
    }
    if ($changed.Count -gt 0) {
      git --no-pager diff --stat @changed | Out-Host
      git --no-pager diff @changed | Out-Host
    }
    Process-Staging -ChangedFiles $changed
    exit 0
  }
  default {
    exit $exitCode
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