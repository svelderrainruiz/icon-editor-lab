#Requires -Version 7.0
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $IsWindows) {
    Write-Host '[vi-compare-hook] Non-Windows environment detected; skipping VI comparison hook.' -ForegroundColor Yellow
    exit 0
}

function Get-RepoRoot {
    $root = $env:WORKSPACE_ROOT
    if (-not $root) { $root = '/mnt/data/repo_local' }
    if (Test-Path -LiteralPath (Join-Path $root '.git')) {
        return (Resolve-Path -LiteralPath $root -ErrorAction Stop).ProviderPath
    }

    $fallback = Join-Path $PSScriptRoot '..' '..'
    return (Resolve-Path -LiteralPath $fallback -ErrorAction Stop).ProviderPath
}

$repoRoot = Get-RepoRoot
Push-Location $repoRoot
try {
    $localCiScript = Join-Path $repoRoot 'local-ci/windows/Invoke-LocalCI.ps1'
    if (-not (Test-Path -LiteralPath $localCiScript -PathType Leaf)) {
        Write-Warning "[vi-compare-hook] local-ci Windows entrypoint not found at $localCiScript; skipping VI comparison."
        exit 0
    }

    Write-Host '[vi-compare-hook] Running Local CI stages 10-Prep and 37-VICompare...' -ForegroundColor Cyan
    & $localCiScript -OnlyStages 10,37
}
catch {
    Write-Error ("[vi-compare-hook] VI comparison hook failed: {0}" -f $_.Exception.Message)
    exit 1
}
finally {
    Pop-Location
}

