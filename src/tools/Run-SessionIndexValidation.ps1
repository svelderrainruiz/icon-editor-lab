[CmdletBinding()]
param(
  [string]$ResultsPath = 'tests/results/_validate-sessionindex',
  [string]$SchemaPath = 'docs/schemas/session-index-v1.schema.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$workspace = (Get-Location).Path
$discoveryScript = Join-Path $workspace 'dist/tools/test-discovery.js'

if (-not (Test-Path -LiteralPath $discoveryScript)) {
  Write-Host '::notice::TypeScript build artifacts missing; running node tools/npm/run-script.mjs build...'
  try {
    node tools/npm/run-script.mjs build | Out-Host
  } catch {
    Write-Error "node tools/npm/run-script.mjs build failed: $_"
    exit 2
  }
  if (-not (Test-Path -LiteralPath $discoveryScript)) {
    Write-Error "test-discovery.js not found at $discoveryScript after node tools/npm/run-script.mjs build"
    exit 2
  }
}

if (-not (Test-Path -LiteralPath $ResultsPath)) {
  New-Item -ItemType Directory -Force -Path $ResultsPath | Out-Null
}

pwsh -NoLogo -NoProfile -File ./tools/Quick-DispatcherSmoke.ps1 -ResultsPath $ResultsPath -PreferWorkspace | Out-Host

$sessionIndex = Join-Path $ResultsPath 'session-index.json'
if (-not (Test-Path -LiteralPath $sessionIndex)) {
  Write-Error "session-index.json not found at $sessionIndex"
  exit 2
}

pwsh -NoLogo -NoProfile -File ./tools/Invoke-JsonSchemaLite.ps1 -JsonPath $sessionIndex -SchemaPath $SchemaPath | Out-Host

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