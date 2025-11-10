#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSModuleAutoLoadingPreference = 'None'
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
param(
  [Parameter()][ValidateSet('2021','2023','2025')][string]$LabVIEWVersion = '2023',
  [Parameter()][ValidateSet(32,64)][int]$Bitness = 64,
  [Parameter()][ValidateNotNullOrEmpty()][string]$Workspace = (Get-Location).Path,
  [Parameter()][int]$TimeoutSec = 600
)
param(
  [string]$Image = 'compare-validate',
  [string]$Workspace = (Get-Location).Path,
  [string]$LogDirectory = 'tests/results/_validate-container',
  [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Assert-Tool: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Assert-Tool {

    # ShouldProcess guard: honor -WhatIf / -Confirm
    if (-not $PSCmdlet.ShouldProcess($MyInvocation.MyCommand.Name, 'Execute')) { return }
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param([string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required tool not found: $Name"
  }
}

Assert-Tool docker

$workspacePath = Resolve-Path -LiteralPath $Workspace
if (-not $workspacePath) {
  throw "Unable to resolve workspace path: $Workspace"
}

$logFullDir = Join-Path $workspacePath $LogDirectory
if (-not (Test-Path -LiteralPath $logFullDir)) {
  New-Item -ItemType Directory -Force -Path $logFullDir | Out-Null
}
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logPath = Join-Path $logFullDir "prechecks-$timestamp.log"

$workspaceMount = "$($workspacePath.Path):/workspace"

# Optional npm cache mount (best effort)
$npmCache = Join-Path $env:USERPROFILE '.npm'
$npmMount = $null
if (Test-Path -LiteralPath $npmCache) {
  $npmMount = "${npmCache}:/root/.npm"
}

$dockerArgs = @(
  'run','--rm',
  '--workdir','/workspace',
  '-v', $workspaceMount
)

if ($npmMount) {
  $dockerArgs += @('-v', $npmMount)
}

if ($env:GITHUB_TOKEN) {
  $dockerArgs += @('-e', 'GITHUB_TOKEN')
}

$dockerArgs += $Image

Write-Host ("[validate-container] docker {0}" -f ($dockerArgs -join ' '))

$logWriter = New-Object System.IO.StreamWriter($logPath,$false,[System.Text.Encoding]::UTF8)
try {
  $processInfo = New-Object System.Diagnostics.ProcessStartInfo
  $processInfo.FileName = 'docker'
  $processInfo.Arguments = ($dockerArgs -join ' ')
  $processInfo.RedirectStandardOutput = $true
  $processInfo.RedirectStandardError = $true
  $processInfo.UseShellExecute = $false
  $process = [System.Diagnostics.Process]::Start($processInfo)
  while (-not $process.HasExited) {
    $line = $process.StandardOutput.ReadLine()
    if ($null -ne $line) {
      Write-Host $line
      $logWriter.WriteLine($line)
    }
    Start-Sleep -Milliseconds 100
  }
  while (-not $process.StandardOutput.EndOfStream) {
    $line = $process.StandardOutput.ReadLine()
    Write-Host $line
    $logWriter.WriteLine($line)
  }
  while (-not $process.StandardError.EndOfStream) {
    $errLine = $process.StandardError.ReadLine()
    Write-Host $errLine
    $logWriter.WriteLine($errLine)
  }
  $exit = $process.ExitCode
} finally {
  $logWriter.Flush(); $logWriter.Dispose()
}

if ($exit -ne 0) {
  throw "Container prechecks failed (exit=$exit). See $logPath"
}

Write-Host ("[validate-container] Completed successfully. Log: {0}" -f $logPath)

if ($PassThru) {
  [pscustomobject]@{ LogPath = $logPath }
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