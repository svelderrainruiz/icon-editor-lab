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
  Quick local smoke test for Invoke-PesterTests.ps1.

.DESCRIPTION
  Creates a temporary tests folder with a tiny passing test, runs the dispatcher,
  prints the JSON summary (selected fields and optionally raw), and cleans up by default.

.PARAMETER Raw
  Also print the raw JSON document.

.PARAMETER Keep
  Keep the temporary folder instead of deleting it.

.PARAMETER ResultsPath
  Optional explicit results path. Defaults to a temp subfolder.

.EXAMPLE
  tools/Quick-DispatcherSmoke.ps1

.EXAMPLE
  tools/Quick-DispatcherSmoke.ps1 -Raw -Keep
#>

param(
  [switch]$Raw,
  [switch]$Keep,
  [string]$ResultsPath,
  [string]$TestsRoot,
  [switch]$PreferWorkspace
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
  $root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
  $dispatcher = Join-Path $root 'Invoke-PesterTests.ps1'
  if (-not (Test-Path -LiteralPath $dispatcher -PathType Leaf)) { throw "Dispatcher not found: $dispatcher" }

  # Choose a temporary root for the ephemeral tests folder
  if (-not $TestsRoot -or [string]::IsNullOrWhiteSpace($TestsRoot)) {
    $tmpBase = $null
    if ($PreferWorkspace -and $env:GITHUB_WORKSPACE) {
      $tmpBase = Join-Path $env:GITHUB_WORKSPACE '.tmp-smoke'
    } elseif ($env:RUNNER_TEMP) {
      $tmpBase = $env:RUNNER_TEMP
    } else {
      $tmpBase = [IO.Path]::GetTempPath()
    }
    $tmp = Join-Path $tmpBase ([guid]::NewGuid().ToString())
  } else {
    $tmp = $TestsRoot
  }
  $testsDir = Join-Path $tmp 'tests'
  New-Item -ItemType Directory -Path $testsDir -Force | Out-Null
  $mini = @(
    "Describe 'Mini' {",
    "  It 'passes' { 1 | Should -Be 1 }",
    "}"
  ) -join [Environment]::NewLine
  Set-Content -LiteralPath (Join-Path $testsDir 'Mini.Tests.ps1') -Value $mini -Encoding UTF8

  if ([string]::IsNullOrWhiteSpace($ResultsPath)) { $ResultsPath = Join-Path $tmp 'results' }
  # Avoid writing to a GitHub step summary during local runs
  $env:DISABLE_STEP_SUMMARY = '1'
  if (-not (Get-Variable -Name includeIntegrationBool -Scope Global -ErrorAction SilentlyContinue)) {
    Set-Variable -Name includeIntegrationBool -Scope Global -Value $false
  }

  Write-Host ("[schema-test] Mini test path: {0}" -f $((Resolve-Path -LiteralPath (Join-Path $testsDir 'Mini.Tests.ps1')).Path))
  & $dispatcher -TestsPath $testsDir -ResultsPath $ResultsPath | Out-Null
  Write-Host ('Exit: {0}' -f $LASTEXITCODE)

  $summaryPath = Join-Path $ResultsPath 'pester-summary.json'
  if (Test-Path -LiteralPath $summaryPath) {
    $json = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    $json | Select-Object schemaVersion,total,passed,failed,errors,skipped,duration_s | Format-List
    if ($Raw) { $json | ConvertTo-Json -Depth 6 | Write-Output }
  } else {
    Write-Warning 'Summary JSON missing'
    if (Test-Path -LiteralPath $ResultsPath) {
      Get-ChildItem -Force $ResultsPath -ErrorAction SilentlyContinue | Format-List | Out-String | Write-Host
    }
  }

  if (-not $Keep) { Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue }
} catch {
  Write-Error $_
  if ($tmp -and -not $Keep) { Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue }
  exit 1
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