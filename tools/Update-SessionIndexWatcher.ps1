<#
.SYNOPSIS
  TODO: Brief synopsis for this tool function/script. (Auto-generated placeholder)
.DESCRIPTION
  TODO: Expand description. Replace this header with real help content.
#>

[CmdletBinding()]
param(
  [string]$ResultsDir = 'tests/results',
  [string]$WatcherJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $WatcherJson) {
  Write-Verbose '[watcher-session] WatcherJson path not provided; skipping.'
  return
}

if (-not (Test-Path -LiteralPath $WatcherJson -PathType Leaf)) {
  Write-Verbose "[watcher-session] Watcher file not found: $WatcherJson"
  return
}

if (-not (Test-Path -LiteralPath $ResultsDir -PathType Container)) {
  New-Item -ItemType Directory -Force -Path $ResultsDir | Out-Null
}

$idxPath = Join-Path $ResultsDir 'session-index.json'
if (-not (Test-Path -LiteralPath $idxPath -PathType Leaf)) {
  try {
    pwsh -NoLogo -NoProfile -File ./tools/Ensure-SessionIndex.ps1 -ResultsDir $ResultsDir | Out-Null
  } catch {
    Write-Warning "[watcher-session] Ensure-SessionIndex failed: $_"
  }
}

if (-not (Test-Path -LiteralPath $idxPath -PathType Leaf)) {
  Write-Warning "[watcher-session] session-index.json still missing at $idxPath"
  return
}

try {
  $idx = Get-Content -LiteralPath $idxPath -Raw | ConvertFrom-Json -ErrorAction Stop
} catch {
  Write-Warning "[watcher-session] Failed to parse session-index.json: $_"
  return
}

try {
  $watch = Get-Content -LiteralPath $WatcherJson -Raw | ConvertFrom-Json -ErrorAction Stop
} catch {
  Write-Warning "[watcher-session] Failed to parse watcher summary: $_"
  return
}

$watchersObject = $null
if ($idx.PSObject.Properties.Name -contains 'watchers') {
  $watchersObject = $idx.watchers
}
if (-not $watchersObject) {
  $watchersObject = [pscustomobject]@{}
}
$watchersObject | Add-Member -NotePropertyName 'rest' -NotePropertyValue $watch -Force
$idx | Add-Member -NotePropertyName 'watchers' -NotePropertyValue $watchersObject -Force

if ($idx.PSObject.Properties.Name -contains 'stepSummary' -and $idx.stepSummary) {
  $summaryLines = @($idx.stepSummary, '', '### Watcher (REST)', "- Status: $($watch.status ?? 'unknown')", "- Conclusion: $($watch.conclusion ?? 'unknown')")
  if ($watch.htmlUrl) { $summaryLines += "- URL: $($watch.htmlUrl)" }
  $idx.stepSummary = ($summaryLines -join "`n")
}

$idx | ConvertTo-Json -Depth 10 | Out-File -FilePath $idxPath -Encoding utf8
Write-Verbose "[watcher-session] Updated session index with REST watcher summary."

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