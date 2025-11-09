#Requires -Version 7.0
[CmdletBinding()]
param(
[Parameter(Mandatory)][ValidateSet('host-prep','missing-in-project','unit-tests','lvcompare')]
  [string]$Kind,
  [Parameter(Mandatory)][string]$Label,
  [Parameter(Mandatory)][string]$Command,
  [Parameter(Mandatory)][string]$Summary,
  [string]$Warnings,
  [string]$TranscriptPath,
  [string]$TelemetryPath,
  [hashtable]$TelemetryLinks,
  [switch]$Aborted,
  [string]$AbortReason,
  [hashtable]$Extra
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
  param([string]$StartPath = (Get-Location).Path)
  try {
    $root = git -C $StartPath rev-parse --show-toplevel 2>$null
    if ($root) { return (Resolve-Path -LiteralPath $root.Trim()).Path }
  } catch {}
  return (Resolve-Path -LiteralPath $StartPath).Path
}

$overrideRoot = [Environment]::GetEnvironmentVariable('COMPAREVI_REPORTS_ROOT')
if (-not [string]::IsNullOrWhiteSpace($overrideRoot)) {
  if (-not (Test-Path -LiteralPath $overrideRoot -PathType Container)) {
    try {
      New-Item -ItemType Directory -Path $overrideRoot -Force | Out-Null
    } catch {}
  }
  try {
    $repoRoot = (Resolve-Path -LiteralPath $overrideRoot -ErrorAction Stop).Path
  } catch {
    $repoRoot = Resolve-RepoRoot
  }
} else {
  $repoRoot = Resolve-RepoRoot
}
$reportsDir = Join-Path $repoRoot 'tests/results/_agent/reports' $Kind
if (-not (Test-Path -LiteralPath $reportsDir -PathType Container)) {
  [void](New-Item -ItemType Directory -Path $reportsDir -Force)
}

$timestamp = Get-Date -Format 'yyyyMMddTHHmmssfff'
$reportPath = Join-Path $reportsDir ("{0}-{1}.json" -f $Label,$timestamp)

$payload = [ordered]@{
  schema        = 'icon-editor/report@v1'
  kind          = $Kind
  label         = $Label
  command       = $Command
  summary       = $Summary
  warnings      = $Warnings
  transcriptPath = $TranscriptPath
  telemetryPath = $TelemetryPath
  aborted       = [bool]$Aborted
  abortReason   = $AbortReason
  timestamp     = (Get-Date).ToString('o')
}

if ($Extra) {
  $payload['extra'] = $Extra
}

if ($Kind -eq 'host-prep' -and $TelemetryLinks -and $TelemetryLinks.Count -gt 0) {
  $payload['devModeTelemetry'] = $TelemetryLinks
}

$payload | ConvertTo-Json -Depth 8 | Out-File -FilePath $reportPath -Encoding utf8

Write-Host ("Report written to: {0}" -f $reportPath) -ForegroundColor DarkGray

return $reportPath
