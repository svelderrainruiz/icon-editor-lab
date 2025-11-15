#Requires -Version 7.0
[CmdletBinding()]
param(
    [switch]$PromptReview
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = $env:WORKSPACE_ROOT
if (-not $root) { $root = '/mnt/data/repo_local' }
if (-not (Test-Path -LiteralPath $root -PathType Container)) {
    $root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..' '..') -ErrorAction Stop).ProviderPath
}

$latest = Join-Path $root 'tests/results/_agent/icon-editor/dev-mode-run/latest-run.json'
if (-not (Test-Path -LiteralPath $latest -PathType Leaf)) {
    throw "Dev-mode telemetry not found at '$latest'. Run a dev-mode task first."
}

try {
    $payload = Get-Content -LiteralPath $latest -Raw | ConvertFrom-Json -ErrorAction Stop
} catch {
    throw "Failed to parse dev-mode telemetry at '$latest': $($_.Exception.Message)"
}

$iconRoot = $payload.lvAddonRootPath
if (-not $iconRoot) {
    throw "Telemetry '$latest' does not contain 'lvAddonRootPath'. Ensure the dev-mode scripts emitted the path summary."
}

$source = if ($payload.PSObject.Properties['lvAddonRootSource']) { $payload.lvAddonRootSource } else { '<unknown>' }
$mode   = if ($payload.PSObject.Properties['lvAddonRootMode'])   { $payload.lvAddonRootMode }   else { '<unknown>' }
$origin = if ($payload.PSObject.Properties['lvAddonRootOrigin']) { $payload.lvAddonRootOrigin } else { '<unknown>' }
$originHost = if ($payload.PSObject.Properties['lvAddonRootHost'])   { $payload.lvAddonRootHost }   else { '<unknown>' }
$lvAddon = if ($payload.PSObject.Properties['lvAddonRootIsLVAddonLab']) { $payload.lvAddonRootIsLVAddonLab } else { '<unknown>' }

Write-Host ("[devscript-check] LvAddonRoot=""{0}"" Source={1} Mode={2} Origin={3} Host={4} LVAddon={5}" -f `
    $iconRoot, $source, $mode, $origin, $originHost, $lvAddon) -ForegroundColor Cyan

if ($PromptReview) {
    Write-Host ""
    Write-Host "Please review the LvAddonRoot path above. Press Enter to acknowledge and continue..." -ForegroundColor Yellow
    [void](Read-Host)
}
