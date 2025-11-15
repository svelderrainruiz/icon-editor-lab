#Requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateSet('Test','Real')]
    [string]$Mode = 'Test',

    [string[]]$EnvironmentNames = @('codesign-dev','codesign-prod'),

    [string]$Repository,

    [string]$GitHubToken,

    [string]$PfxPath,

    [string]$PfxPassword,

    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RepoSlug {
    param(
        [string]$ExplicitRepository
    )

    if ($ExplicitRepository -and $ExplicitRepository -match '^[^/]+/[^/]+$') {
        return $ExplicitRepository
    }

    if ($env:GITHUB_REPOSITORY) {
        return $env:GITHUB_REPOSITORY
    }

    throw "Repository slug not provided. Use -Repository or set GITHUB_REPOSITORY."
}

function Ensure-GhCli {
    param(
        [string]$Token
    )

    if ($DryRun) {
        return $null
    }

    if (-not $Token) {
        throw "GITHUB_TOKEN or -GitHubToken is required to set environment secrets when not using -DryRun."
    }

    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $gh) {
        throw "GitHub CLI (gh) not found on PATH. Install gh or re-run with -DryRun to see manual commands."
    }

    $oldToken = $env:GITHUB_TOKEN
    $env:GITHUB_TOKEN = $Token
    try {
        & $gh.Path auth status 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "gh auth status failed (exit $LASTEXITCODE). Ensure the token has repo + secrets:write scope."
        }
    } catch {
        throw "Failed to validate gh authentication: $($_.Exception.Message)"
    } finally {
        if (-not $oldToken) {
            $env:GITHUB_TOKEN = $Token
        } else {
            $env:GITHUB_TOKEN = $oldToken
        }
        # Always leave the token value available for subsequent gh calls.
        $env:GITHUB_TOKEN = $Token
    }

    return $gh
}

function New-TestCodesignMaterial {
    param(
        [string]$RepoRoot
    )

    $tempDir = Join-Path ([IO.Path]::GetTempPath()) ("codesign-test-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    $generator = Join-Path $RepoRoot 'tools' 'Generate-TestCodeSignCert.ps1'
    if (-not (Test-Path -LiteralPath $generator -PathType Leaf)) {
        throw "Generator script not found at $generator"
    }

    pwsh -NoLogo -NoProfile -File $generator -OutDir $tempDir -EmitEnv -EmitJson -Quiet | Out-Null

    $b64Path = Join-Path $tempDir 'WIN_CODESIGN_PFX_B64.txt'
    $pwdPath = Join-Path $tempDir 'WIN_CODESIGN_PFX_PASSWORD.txt'
    return [pscustomobject]@{
        TempDir        = $tempDir
        B64Path        = $b64Path
        PasswordPath   = $pwdPath
        PfxBase64Value = (Get-Content -LiteralPath $b64Path -Raw).Trim()
        PasswordValue  = (Get-Content -LiteralPath $pwdPath -Raw)
    }
}

function New-RealCodesignMaterial {
    param(
        [string]$InputPath,
        [string]$Password
    )

    if (-not (Test-Path -LiteralPath $InputPath -PathType Leaf)) {
        throw "PFX file not found at $InputPath"
    }
    if (-not $Password) {
        throw "Pfx password must be provided when Mode=Real."
    }

    $bytes = [IO.File]::ReadAllBytes($InputPath)
    $b64 = [Convert]::ToBase64String($bytes)
    $tempDir = Join-Path ([IO.Path]::GetTempPath()) ("codesign-real-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    $b64Path = Join-Path $tempDir 'WIN_CODESIGN_PFX_B64.txt'
    $pwdPath = Join-Path $tempDir 'WIN_CODESIGN_PFX_PASSWORD.txt'
    Set-Content -LiteralPath $b64Path -Value $b64 -Encoding UTF8
    Set-Content -LiteralPath $pwdPath -Value $Password -Encoding UTF8

    return [pscustomobject]@{
        TempDir        = $tempDir
        B64Path        = $b64Path
        PasswordPath   = $pwdPath
        PfxBase64Value = $b64
        PasswordValue  = $Password
    }
}

$repoSlug = Get-RepoSlug -ExplicitRepository $Repository
$tokenToUse = if ($GitHubToken) { $GitHubToken } elseif ($env:GITHUB_TOKEN) { $env:GITHUB_TOKEN } else { $null }
$ghCli = Ensure-GhCli -Token $tokenToUse

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath

$material = $null
try {
    if ($Mode -eq 'Test') {
        Write-Host "[codesign] Generating throwaway test certificate..."
        $material = New-TestCodesignMaterial -RepoRoot $repoRoot
    } else {
        Write-Host "[codesign] Using provided PFX for real provisioning..."
        if (-not $PfxPath) {
            throw "Mode=Real requires -PfxPath."
        }
        $material = New-RealCodesignMaterial -InputPath (Resolve-Path -LiteralPath $PfxPath).Path -Password $PfxPassword
    }

    $envNames = @($EnvironmentNames | Where-Object { $_ -and $_.Trim() } | Sort-Object -Unique)
    if (-not $envNames -or $envNames.Length -eq 0) {
        throw "At least one environment name must be provided."
    }

    Write-Host "[codesign] Target repository: $repoSlug"
    Write-Host "[codesign] Target environments: $($envNames -join ', ')"

    if ($DryRun) {
        Write-Host "[codesign] DryRun enabled. No secrets will be written."
        Write-Host "[codesign] Run the following commands manually once ready (requires gh auth with repo + secrets:write):"
        foreach ($envName in $envNames) {
            Write-Host ""
            Write-Host "# Ensure environment $envName exists"
            Write-Host "gh api repos/$repoSlug/environments/$envName -X PUT -f name=$envName"
            Write-Host "# Set secrets for $envName"
            Write-Host "gh secret set -e $envName WIN_CODESIGN_PFX_B64      --repo $repoSlug --body-file '$($material.B64Path)'"
            Write-Host "gh secret set -e $envName WIN_CODESIGN_PFX_PASSWORD --repo $repoSlug --body-file '$($material.PasswordPath)'"
        }
        return
    }

    foreach ($envName in $envNames) {
        Write-Host "[codesign] Ensuring environment '$envName' exists..."
        & $ghCli.Path api "repos/$repoSlug/environments/$envName" -X PUT -f "name=$envName" | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create/confirm environment $envName (exit $LASTEXITCODE)."
        }
    }

    foreach ($envName in $envNames) {
        Write-Host "[codesign] Setting secrets for environment '$envName'..."
        & $ghCli.Path secret set -e $envName WIN_CODESIGN_PFX_B64      --repo $repoSlug -b $material.PfxBase64Value | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Failed to set WIN_CODESIGN_PFX_B64 in $envName." }
        & $ghCli.Path secret set -e $envName WIN_CODESIGN_PFX_PASSWORD --repo $repoSlug -b $material.PasswordValue  | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Failed to set WIN_CODESIGN_PFX_PASSWORD in $envName." }
    }

    Write-Host "[codesign] Provisioning completed."
} finally {
    if ($material -and $material.TempDir -and (Test-Path -LiteralPath $material.TempDir -PathType Container)) {
        try { Remove-Item -LiteralPath $material.TempDir -Recurse -Force -ErrorAction SilentlyContinue } catch { }
    }
}
