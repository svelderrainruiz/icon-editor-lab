#Requires -Version 7.0
<#
.SYNOPSIS
Creates or refreshes the local-ci handshake workflow in another repository.

.DESCRIPTION
Copies .github/workflows/local-ci-handshake.yml from this repo into a target
repo (default: current working directory). Optionally override the workflow
filename and force overwrites. Use -WindowsRunsOn '[self-hosted, windows]'
to preconfigure the Windows job for a self-hosted runner label.

.EXAMPLE
pwsh -File local-ci/scripts/New-HandshakeWorkflow.ps1 `
  -TargetRepoRoot C:\src\myfork `
  -WindowsRunsOn '[self-hosted, windows]'
#>
[CmdletBinding()]
param(
    [string]$TargetRepoRoot = (Get-Location).Path,
    [string]$WorkflowName = 'local-ci-handshake.yml',
    [string]$WindowsRunsOn,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    param([string]$Path)
    if (-not $Path) { throw "TargetRepoRoot not provided." }
    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop
    return $resolved.ProviderPath
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-RepoRoot -Path (Join-Path $scriptRoot '..' '..')
$sourceWorkflow = Join-Path $repoRoot '.github/workflows/local-ci-handshake.yml'
if (-not (Test-Path -LiteralPath $sourceWorkflow -PathType Leaf)) {
    throw "Source workflow not found at $sourceWorkflow. Update the script if the template was moved."
}

$targetRepo = Resolve-RepoRoot -Path $TargetRepoRoot
$workflowDir = Join-Path $targetRepo '.github/workflows'
if (-not (Test-Path -LiteralPath $workflowDir -PathType Container)) {
    New-Item -ItemType Directory -Path $workflowDir -Force | Out-Null
}
$destinationPath = Join-Path $workflowDir $WorkflowName
if ((Test-Path -LiteralPath $destinationPath) -and -not $Force) {
    throw "Workflow '$destinationPath' already exists. Use -Force to overwrite."
}

$content = Get-Content -LiteralPath $sourceWorkflow -Raw
if ($WindowsRunsOn) {
    $lines = $content -split "`n"
    $replaced = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $trimmed = $lines[$i].Trim()
        if (-not $replaced -and $trimmed -match '^runs-on:\s*windows-2022\s*$') {
            $indent = $lines[$i] -replace 'runs-on:.*$', ''
            $lines[$i] = "{0}runs-on: {1}" -f $indent, $WindowsRunsOn
            $replaced = $true
        }
    }
    if (-not $replaced) {
        Write-Warning "Did not find a 'runs-on: windows-2022' line to rewrite. The template layout may have changed."
    } else {
        $content = ($lines -join "`n")
    }
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($destinationPath, $content, $utf8)

Write-Host ("Handshake workflow written to {0}" -f $destinationPath)
if ($WindowsRunsOn) {
    Write-Host ("Windows job now targets: {0}" -f $WindowsRunsOn)
}
Write-Host "Remember to commit the new workflow in the target repository."
