#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$UbuntuRunPath,
    [string]$UbuntuRunsRoot,
    [string]$InvokeScript,
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    param([string]$Start = $PSScriptRoot)
    try {
        $resolved = git -C $Start rev-parse --show-toplevel 2>$null
        if ($resolved) { return $resolved.Trim() }
    } catch {}
    return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..' '..')).Path
}

function Resolve-UbuntuRun {
    param(
        [string]$ExplicitPath,
        [string]$RunsRoot
    )

    if ($ExplicitPath) {
        $candidate = Resolve-Path -LiteralPath $ExplicitPath -ErrorAction Stop
        if (Test-Path -LiteralPath $candidate -PathType Container) {
            $manifest = Join-Path $candidate 'ubuntu-run.json'
            if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) {
                throw "Directory '$candidate' does not contain ubuntu-run.json"
            }
            return $candidate
        }
        if ($candidate.ProviderPath -like '*.json') {
            return (Split-Path -Parent $candidate.ProviderPath)
        }
        return Split-Path -Parent $candidate.ProviderPath
    }

    if (-not (Test-Path -LiteralPath $RunsRoot -PathType Container)) {
        throw "Ubuntu runs root '$RunsRoot' not found. Provide -UbuntuRunPath."
    }

    $latest = Get-ChildItem -LiteralPath $RunsRoot -Directory | Sort-Object Name -Descending | Select-Object -First 1
    if (-not $latest) {
        throw "No Ubuntu runs found under '$RunsRoot'."
    }
    $manifest = Join-Path $latest.FullName 'ubuntu-run.json'
    if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) {
        throw "Latest run '$($latest.FullName)' is missing ubuntu-run.json."
    }
    return $latest.FullName
}

$repoRoot = Resolve-RepoRoot
if (-not $InvokeScript) {
    $InvokeScript = Join-Path $PSScriptRoot '..' 'Invoke-LocalCI.ps1'
}
$InvokeScript = (Resolve-Path -LiteralPath $InvokeScript).ProviderPath

if (-not $UbuntuRunsRoot) {
    $UbuntuRunsRoot = Join-Path $repoRoot 'out/local-ci-ubuntu'
}

$resolvedRun = Resolve-UbuntuRun -ExplicitPath $UbuntuRunPath -RunsRoot $UbuntuRunsRoot
Write-Host "Importing Ubuntu run: $resolvedRun"
$env:LOCALCI_IMPORT_UBUNTU_RUN = $resolvedRun

if ($WhatIf) {
    Write-Host "[DRY RUN] Would invoke $InvokeScript with LOCALCI_IMPORT_UBUNTU_RUN=$resolvedRun"
    return
}

& $InvokeScript
exit $LASTEXITCODE
