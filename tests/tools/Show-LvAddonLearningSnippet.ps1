#Requires -Version 7.0
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = $env:WORKSPACE_ROOT
if (-not $root) {
    $root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..' '..') -ErrorAction Stop).ProviderPath
}

$snippetPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-learning-snippet.json'
if (-not (Test-Path -LiteralPath $snippetPath -PathType Leaf)) {
    Write-Warning ("[lvaddon/learn] Learning snippet not found at '{0}'. Run Collect-LvAddonLearningData.ps1 first." -f $snippetPath)
    return
}

try {
    $snippet = Get-Content -LiteralPath $snippetPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
} catch {
    throw "[lvaddon/learn] Failed to parse learning snippet at '$snippetPath': $($_.Exception.Message)"
}

Write-Host "[lvaddon/learn] Snippet path: $snippetPath" -ForegroundColor DarkGray
Write-Host ""

if ($snippet.AgentInstructions) {
    Write-Host "=== AgentInstructions ===" -ForegroundColor Cyan
    Write-Host $snippet.AgentInstructions
    Write-Host ""
}

if (-not $snippet.SampleRecords -or $snippet.SampleRecords.Count -eq 0) {
    Write-Warning "[lvaddon/learn] No SampleRecords found in snippet."
    return
}

Write-Host "=== SampleRecords (compact view) ===" -ForegroundColor Cyan

foreach ($rec in $snippet.SampleRecords) {
    $argsPreview = if ($rec.Args -and $rec.Args.Count -gt 0) { ($rec.Args -join ' ') } else { '<none>' }
    Write-Host ("- Mode={0} Operation={1} LvVersion={2} Bitness={3}" -f `
        $rec.Mode, $rec.Operation, $rec.LvVersion, $rec.Bitness)
    Write-Host ("  LvAddonRoot={0}" -f $rec.LvAddonRoot)
    Write-Host ("  Script={0}" -f $rec.Script)
    Write-Host ("  Args={0}" -f $argsPreview)
    Write-Host ""
}

