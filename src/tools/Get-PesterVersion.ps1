[CmdletBinding()]
param(
  [switch]$EmitEnv,
  [switch]$EmitOutput
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$defaultVersion = '5.7.1'
$policyPath = Join-Path $PSScriptRoot 'policy' 'tool-versions.json'
$resolved = $defaultVersion

if (Test-Path -LiteralPath $policyPath) {
  try {
    $raw = Get-Content -LiteralPath $policyPath -Raw -Encoding UTF8
    if ($raw) {
      $parsed = $raw | ConvertFrom-Json -ErrorAction Stop
      if ($parsed -and $parsed.pester) {
        $candidate = [string]$parsed.pester
        if (-not [string]::IsNullOrWhiteSpace($candidate)) {
          $resolved = $candidate
        }
      }
    }
  } catch {
    Write-Verbose ("Fell back to default Pester version because policy load failed: {0}" -f $_.Exception.Message)
  }
}

if ($EmitEnv -and $env:GITHUB_ENV) {
  "PESTER_VERSION=$resolved" | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding utf8
}

if ($EmitOutput -and $env:GITHUB_OUTPUT) {
  "version=$resolved" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
}

if (-not $EmitEnv -and -not $EmitOutput) {
  Write-Output $resolved
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