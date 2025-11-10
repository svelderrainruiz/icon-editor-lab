<#
.SYNOPSIS
  TODO: Brief synopsis for this tool function/script. (Auto-generated placeholder)
.DESCRIPTION
  TODO: Expand description. Replace this header with real help content.
#>

#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSModuleAutoLoadingPreference = 'None'
[CmdletBinding()]
param(
    [string]$TargetPath = 'fixtures/vi-stage/bd-cosmetic/Head.vi',
    [string]$StartRef = 'HEAD',
    [int]$MaxPairs = 6,
    [int]$MaxSignalPairs = 2,
    [ValidateSet('include','collapse','skip')]
    [string]$NoisePolicy = 'collapse',
    [string]$ResultsDir,
    [switch]$RenderReport,
    [switch]$KeepArtifacts,
    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
if (-not $scriptDir) { throw 'Unable to locate script directory.' }
$repoRoot = Split-Path -Parent $scriptDir
if (-not $repoRoot) { throw 'Unable to determine repository root.' }

$stubPath = Join-Path $repoRoot 'tests/stubs/Invoke-LVCompare.stub.ps1'
if (-not (Test-Path -LiteralPath $stubPath -PathType Leaf)) {
    throw "Stub LVCompare script not found at $stubPath"
}

$resultsRoot = if ($ResultsDir) {
    if ([System.IO.Path]::IsPathRooted($ResultsDir)) { $ResultsDir } else { Join-Path $repoRoot $ResultsDir }
} else {
    Join-Path $repoRoot 'tests/results/_agent/history-stub'
}

if (Test-Path -LiteralPath $resultsRoot) {
    Remove-Item -LiteralPath $resultsRoot -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Path $resultsRoot -Force | Out-Null

$historyScript = Join-Path $repoRoot 'tools/Compare-VIHistory.ps1'
if (-not (Test-Path -LiteralPath $historyScript -PathType Leaf)) {
    throw "Compare-VIHistory.ps1 not found at $historyScript"
}

$arguments = @(
    '-NoLogo','-NoProfile','-File', $historyScript,
    '-TargetPath', $TargetPath,
    '-StartRef', $StartRef,
    '-MaxPairs', $MaxPairs,
    '-MaxSignalPairs', $MaxSignalPairs,
    '-NoisePolicy', $NoisePolicy,
    '-ResultsDir', $resultsRoot,
    '-InvokeScriptPath', $stubPath,
    '-Detailed'
)

if ($RenderReport.IsPresent) { $arguments += '-RenderReport' }
if ($KeepArtifacts.IsPresent) { $arguments += '-KeepArtifactsOnNoDiff' }
if ($Quiet.IsPresent) { $arguments += '-Quiet' }

Write-Verbose ("Running Compare-VIHistory with arguments:`n{0}" -f ($arguments -join ' '))

$proc = Start-Process -FilePath 'pwsh' -ArgumentList $arguments -WorkingDirectory $repoRoot -NoNewWindow -Wait -PassThru
if ($proc.ExitCode -ne 0) {
    throw "Compare-VIHistory.ps1 exited with code $($proc.ExitCode)"
}

$manifestPath = Join-Path $resultsRoot 'manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Aggregate manifest not found at $manifestPath"
}
$aggregate = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -Depth 8

$summary = [ordered]@{
    manifestPath    = $manifestPath
    targetPath      = $aggregate.targetPath
    startRef        = $aggregate.startRef
    maxSignalPairs  = $aggregate.maxSignalPairs
    noisePolicy     = $aggregate.noisePolicy
    totalProcessed  = $aggregate.stats.processed
    totalDiffs      = $aggregate.stats.diffs
    signalDiffs     = $aggregate.stats.signalDiffs
    noiseCollapsed  = $aggregate.stats.noiseCollapsed
    modes           = @()
}

foreach ($mode in $aggregate.modes) {
    $modeInfo = [ordered]@{
        name           = $mode.name
        processed      = $mode.stats.processed
        diffs          = $mode.stats.diffs
        signalDiffs    = $mode.stats.signalDiffs
        noiseCollapsed = $mode.stats.noiseCollapsed
        stopReason     = $mode.stats.stopReason
        manifestPath   = $mode.manifestPath
    }
    $summary.modes += [pscustomobject]$modeInfo
}

Write-Host ''
Write-Host '=== History Signal/Noise Summary ===' -ForegroundColor Cyan
Write-Host ("Target Path     : {0}" -f $summary.targetPath)
Write-Host ("Start Ref       : {0}" -f $summary.startRef)
Write-Host ("Max SignalPairs : {0}" -f $summary.maxSignalPairs)
Write-Host ("Noise Policy    : {0}" -f $summary.noisePolicy)
Write-Host ("Total processed : {0}" -f $summary.totalProcessed)
Write-Host ("Signal diffs    : {0}" -f $summary.signalDiffs)
Write-Host ("Noise collapsed : {0}" -f $summary.noiseCollapsed)
Write-Host ("Aggregate manifest: {0}" -f $summary.manifestPath)
Write-Host ''
foreach ($mode in $summary.modes) {
    Write-Host ("Mode '{0}': processed={1}, diffs={2}, signal={3}, collapsedNoise={4}, stopReason={5}" -f `
        $mode.name, $mode.processed, $mode.diffs, $mode.signalDiffs, $mode.noiseCollapsed, $mode.stopReason)
    Write-Host ("    manifest: {0}" -f $mode.manifestPath)
}

Write-Host ''
Write-Host ("Results directory: {0}" -f $resultsRoot)

return [pscustomobject]$summary

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