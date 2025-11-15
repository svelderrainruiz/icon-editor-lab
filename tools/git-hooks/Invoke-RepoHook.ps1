#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('pre-commit','pre-push','vi-compare')]
    [string]$HookName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
    $root = $env:WORKSPACE_ROOT
    if (-not $root) { $root = '/mnt/data/repo_local' }
    if (Test-Path -LiteralPath (Join-Path $root '.git')) {
        return (Resolve-Path -LiteralPath $root -ErrorAction Stop).ProviderPath
    }

    $fallback = Join-Path $PSScriptRoot '..' '..'
    return (Resolve-Path -LiteralPath $fallback -ErrorAction Stop).ProviderPath
}

function Get-Toggle {
    param(
        [string]$Name,
        [bool]$Default = $false
    )
    $value = [Environment]::GetEnvironmentVariable($Name, 'Process')
    if ([string]::IsNullOrWhiteSpace($value)) { return $Default }
    switch ($value.Trim().ToLowerInvariant()) {
        '1' { return $true }
        'true' { return $true }
        'yes' { return $true }
        'on' { return $true }
        '0' { return $false }
        'false' { return $false }
        'no' { return $false }
        'off' { return $false }
        default { return $Default }
    }
}

$repoRoot = Get-RepoRoot
Push-Location $repoRoot
try {
    $hooksRoot = Join-Path $repoRoot 'tools/git-hooks'
    $localCiRoot = Join-Path $repoRoot 'tools/local-ci'

    switch ($HookName) {
        'pre-commit' {
            $scriptPath = Join-Path $hooksRoot 'Invoke-PreCommitChecks.ps1'
            if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
                Write-Warning "Repo hook: pre-commit checks script not found at $scriptPath; skipping."
                break
            }
            & $scriptPath
        }
        'pre-push' {
            $prePushScript = Join-Path $hooksRoot 'Invoke-PrePushChecks.ps1'
            if (-not (Test-Path -LiteralPath $prePushScript -PathType Leaf)) {
                Write-Warning "Repo hook: pre-push checks script not found at $prePushScript; skipping."
            } else {
                & $prePushScript
            }

            if (Get-Toggle -Name 'ICONEDITORLAB_VICOMPARISON_HOOK' -Default:$false) {
                $viHook = Join-Path $localCiRoot 'Invoke-ViCompareHook.ps1'
                if (-not (Test-Path -LiteralPath $viHook -PathType Leaf)) {
                    Write-Warning "Repo hook: VI comparison hook not found at $viHook; skipping VI comparison."
                } else {
                    & $viHook
                }
            }
        }
        'vi-compare' {
            $viHook = Join-Path $localCiRoot 'Invoke-ViCompareHook.ps1'
            if (-not (Test-Path -LiteralPath $viHook -PathType Leaf)) {
                Write-Warning "Repo hook: VI comparison hook not found at $viHook; skipping."
                break
            }
            & $viHook
        }
    }
}
finally {
    Pop-Location
}

