#Requires -Version 7.0
[CmdletBinding()]
param()

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

$repoRoot = Get-RepoRoot
$gitDir   = Join-Path $repoRoot '.git'
if (-not (Test-Path -LiteralPath $gitDir -PathType Container)) {
    throw "Git directory not found at $gitDir. Run this from a cloned repository."
}

$hooksDir = Join-Path $gitDir 'hooks'
if (-not (Test-Path -LiteralPath $hooksDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $hooksDir | Out-Null
}

$preCommitPath = Join-Path $hooksDir 'pre-commit'
$prePushPath   = Join-Path $hooksDir 'pre-push'

$preCommitContent = @'
#!/usr/bin/env bash
set -euo pipefail
repo_root="$(git rev-parse --show-toplevel)"
pwsh -NoLogo -NoProfile -File "$repo_root/tools/git-hooks/Invoke-RepoHook.ps1" -HookName pre-commit
'@

$prePushContent = @'
#!/usr/bin/env bash
set -euo pipefail
repo_root="$(git rev-parse --show-toplevel)"
if command -v git-lfs >/dev/null 2>&1; then
  git lfs pre-push "$@"
fi
pwsh -NoLogo -NoProfile -File "$repo_root/tools/git-hooks/Invoke-RepoHook.ps1" -HookName pre-push
'@

Set-Content -LiteralPath $preCommitPath -Value $preCommitContent -Encoding UTF8
Set-Content -LiteralPath $prePushPath   -Value $prePushContent   -Encoding UTF8

if (-not $IsWindows) {
    try {
        & chmod +x $preCommitPath $prePushPath 2>$null
    } catch {
        Write-Warning "Failed to mark hooks as executable; you may need to run 'chmod +x .git/hooks/pre-*' manually."
    }
}

Write-Host "Installed Git hooks:"
Write-Host "  pre-commit -> $preCommitPath"
Write-Host "  pre-push   -> $prePushPath"
Write-Host ""
Write-Host "Pre-commit: enforces workspace path policy for PowerShell scripts."
Write-Host "Pre-push  : runs Invoke-Pester -Path tests -CI and, when ICONEDITORLAB_VICOMPARISON_HOOK=1, triggers the VI comparison hook."
Write-Host ""
Write-Host "To temporarily skip locally, set ICONEDITORLAB_SKIP_PRECOMMIT=1 or ICONEDITORLAB_SKIP_PREPUSH=1."
*** Update File: README.md
