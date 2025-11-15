#Requires -Version 7.0
[CmdletBinding()]
param(
    [switch]$Open,
    [switch]$RawJson
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
    Write-Host "[devmode] No dev-mode telemetry found at '$latest'." -ForegroundColor DarkGray
    return
}

try {
    $payload = Get-Content -LiteralPath $latest -Raw | ConvertFrom-Json -ErrorAction Stop
} catch {
    Write-Warning ("[devmode] Failed to parse dev-mode telemetry at '{0}': {1}" -f $latest, $_.Exception.Message)
    return
}

$mode       = if ($payload.PSObject.Properties['mode'])       { $payload.mode }       else { '<unknown>' }
$operation  = if ($payload.PSObject.Properties['operation'])  { $payload.operation }  else { '<unknown>' }
$status     = if ($payload.PSObject.Properties['status'])     { $payload.status }     else { '<unknown>' }
$reqVers    = if ($payload.PSObject.Properties['requestedVersions']) { $payload.requestedVersions } else { $null }
$reqBits    = if ($payload.PSObject.Properties['requestedBitness'])  { $payload.requestedBitness }  else { $null }
$error      = if ($payload.PSObject.Properties['error'])      { $payload.error }      else { $null }
$errorSummary = $null
if ($payload.PSObject.Properties['errorSummary']) {
    $errorSummary = $payload.errorSummary
} elseif ($error) {
    $lines = $error -split "(`r`n|`n)"
    $errorSummary = $lines | Where-Object {
        $_ -and (
            $_ -match 'Error:' -or
            $_ -match 'Rogue LabVIEW' -or
            $_ -match 'Timed out waiting for app to connect to g-cli'
        )
    } | Select-Object -First 1
    if (-not $errorSummary) {
        $errorSummary = $lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1
    }
}

$summaryLine = "mode={0}; operation={1}; status={2}" -f $mode, $operation, $status
Write-Host ("[devmode] Last run: {0}" -f $summaryLine)

if ($reqVers -or $reqBits) {
    $versText = if ($reqVers) { ($reqVers -join ',') } else { '<auto>' }
    $bitsText = if ($reqBits) { ($reqBits -join ',') } else { '<auto>' }
    Write-Host ("[devmode] Targets: versions={0}; bitness={1}" -f $versText, $bitsText) -ForegroundColor DarkGray
}

if ($errorSummary) {
    Write-Host ("[devmode] Error summary: {0}" -f $errorSummary.Trim()) -ForegroundColor Red
} elseif ($error) {
    Write-Host "[devmode] Error summary unavailable; see full error below." -ForegroundColor Red
}

$statePath = if ($payload.PSObject.Properties['statePath']) { $payload.statePath } else { $null }
if ($statePath) {
    Write-Host ("[devmode] State file: {0}" -f $statePath) -ForegroundColor DarkGray
}

if ($payload.PSObject.Properties['lvAddonRootPath']) {
    $rootSource = if ($payload.PSObject.Properties['lvAddonRootSource']) { $payload.lvAddonRootSource } else { '<unknown>' }
    $rootMode   = if ($payload.PSObject.Properties['lvAddonRootMode'])   { $payload.lvAddonRootMode }   else { '<unknown>' }
    $rootOrigin = if ($payload.PSObject.Properties['lvAddonRootOrigin']) { $payload.lvAddonRootOrigin } else { '<unknown>' }
    $rootHost   = if ($payload.PSObject.Properties['lvAddonRootHost'])   { $payload.lvAddonRootHost }   else { '<unknown>' }
    $rootLvAddon = if ($payload.PSObject.Properties['lvAddonRootIsLVAddonLab']) { $payload.lvAddonRootIsLVAddonLab } else { '<unknown>' }
    Write-Host ("[devmode] LvAddonRoot: {0}; source={1}; mode={2}; origin={3}; host={4}; LVAddon={5}" -f `
        $payload.lvAddonRootPath,
        $rootSource,
        $rootMode,
        $rootOrigin,
        $rootHost,
        $rootLvAddon) -ForegroundColor DarkCyan
}

if ($payload.PSObject.Properties['verificationSummary']) {
    $vs = $payload.verificationSummary
    $present = if ($vs.PSObject.Properties['presentCount']) { $vs.presentCount } else { 0 }
    $contains = if ($vs.PSObject.Properties['containsIconEditorCount']) { $vs.containsIconEditorCount } else { 0 }
    Write-Host ("[devmode] Verification: present={0}; containsIconEditor={1}" -f $present, $contains) -ForegroundColor DarkGray
}

Write-Host ("[devmode] Telemetry JSON: {0}" -f $latest) -ForegroundColor DarkGray

if ($RawJson) {
    Write-Host ""
    Write-Host "[devmode] Raw telemetry payload:" -ForegroundColor DarkGray
    $payload | ConvertTo-Json -Depth 7
}

if ($Open) {
    try {
        if (Get-Command code -ErrorAction SilentlyContinue) {
            & code -g $latest | Out-Null
        } elseif ($IsWindows) {
            Start-Process -FilePath $latest | Out-Null
        } else {
            Write-Host "[devmode] Unable to auto-open telemetry JSON (no 'code' on PATH)." -ForegroundColor DarkGray
        }
    } catch {
        Write-Warning ("[devmode] Failed to open telemetry JSON: {0}" -f $_.Exception.Message)
    }
}
