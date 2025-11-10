Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSModuleAutoLoadingPreference = 'None'
<#
.SYNOPSIS
  Append a step summary block that captures a rerun command and workflow link.
.DESCRIPTION
  Builds a Markdown summary containing a heading, the gh workflow run command,
  an optional sample_id omission notice, and a workflow hyperlink when the file
  name is known. Designed for use in GitHub Actions steps that already run
  within PowerShell (avoids nested pwsh invocations).
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$WorkflowName,
  [string]$WorkflowFile,
  [string]$RefName,
  [string]$SampleId,
  [string]$IncludeIntegration,
  [string]$WorkflowRef,
  [string]$Repository,
  [switch]$EmitSampleNote
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $env:GITHUB_STEP_SUMMARY) {
  return
}

if (-not $RefName) { $RefName = $env:GITHUB_REF_NAME }
if (-not $Repository) { $Repository = $env:GITHUB_REPOSITORY }
if (-not $WorkflowRef) { $WorkflowRef = $env:GITHUB_WORKFLOW_REF }

$cmdParts = [System.Collections.Generic.List[string]]::new()
$cmdParts.Add([string]::Concat('gh workflow run "', $WorkflowName, '"'))
if ($RefName) {
  $cmdParts.Add([string]::Concat('-r "', $RefName, '"'))
}
if ($IncludeIntegration) {
  $cmdParts.Add([string]::Concat('-f include_integration=', $IncludeIntegration))
}
if ($SampleId) {
  $cmdParts.Add([string]::Concat('-f sample_id=', $SampleId))
}
$command = [string]::Join(' ', $cmdParts)

$workflowPath = $WorkflowFile
if (-not $workflowPath -and $WorkflowRef -match '\.github/workflows/(?<path>[^@]+)@') {
  $workflowPath = $Matches['path']
}

$sb = [System.Text.StringBuilder]::new()
$null = $sb.AppendLine('### Re-run With Same Inputs')
$null = $sb.AppendLine()
$null = $sb.Append('- Command: `')
$null = $sb.Append($command)
$null = $sb.AppendLine('`')
if ($EmitSampleNote.IsPresent -and -not $SampleId) {
  $null = $sb.AppendLine('- sample_id omitted; workflow will auto-generate if supported.')
}
if ($Repository -and $workflowPath) {
  $null = $sb.Append('- Workflow: https://github.com/')
  $null = $sb.Append($Repository)
  $null = $sb.Append('/actions/workflows/')
  $null = $sb.AppendLine($workflowPath)
}

$summary = $sb.ToString().TrimEnd("`r", "`n")
if ($summary) {
  $summary | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
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