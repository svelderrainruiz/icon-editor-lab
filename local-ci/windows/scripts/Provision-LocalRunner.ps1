<#
.SYNOPSIS
  Bootstraps a Windows self-hosted runner for the Local CI handshake.
.DESCRIPTION
  Installs PowerShell 7.4, Node.js 20.x LTS, Python 3.11+, Pester/ThreadJob modules,
  and optionally imports the signing certificate. Uses winget when available, falls
  back to Chocolatey if requested.
.PARAMETER RunnerRoot
  Directory that hosts the repository and actions runner.
.PARAMETER SigningCertPath
  Optional .pfx path to import into the CurrentUser\My store.
.PARAMETER SigningCertPassword
  Password for `SigningCertPath`.
.PARAMETER UseChocolatey
  Skip winget and use Chocolatey packages instead.
.PARAMETER SkipModuleBootstrap
  Skip installing Pester/ThreadJob modules (useful when offline).
#>
param(
    [string]$RunnerRoot = 'C:\local-ci',
    [string]$SigningCertPath = '',
    [string]$SigningCertPassword = '',
    [switch]$UseChocolatey,
    [switch]$SkipModuleBootstrap
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Ensure-Command($name) {
    if (Get-Command $name -ErrorAction SilentlyContinue) { return $true }
    return $false
}

function Install-WithWinget($id, $name) {
    if (-not (Test-Path $env:ProgramFiles)) { throw "Winget requires Program Files path" }
    Write-Host "[provision] Installing $name via winget..."
    $args = @('install', '--id', $id, '--accept-package-agreements', '--accept-source-agreements')
    winget @args
}

function Install-WithChocolatey($package) {
    if (-not (Get-Command choco.exe -ErrorAction SilentlyContinue)) {
        throw 'Chocolatey is not installed on this host.'
    }
    Write-Host "[provision] Installing $package via Chocolatey..."
    choco install $package -y --no-progress
}

function Install-Tool($check, $wingetId, $hgName, $chocoName) {
    if (Ensure-Command $check) {
        Write-Host "[provision] $hgName already available."
        return
    }
    if (-not $UseChocolatey) {
        Install-WithWinget $wingetId $hgName
    } else {
        Install-WithChocolatey $chocoName
    }
}

if (-not (Join-Path $RunnerRoot 'README.txt' | Out-Null)) {
    Write-Host "[provision] Ensuring runner root exists: $RunnerRoot"
    New-Item -ItemType Directory -Path $RunnerRoot -Force | Out-Null
}

if (-not $UseChocolatey -and -not (Ensure-Command winget)) {
    throw 'Winget is not available. Install winget or use -UseChocolatey.'
}

Install-Tool -check pwsh -wingetId 'Microsoft.Powershell' -hgName 'PowerShell 7' -chocoName 'powershell-core'
Install-Tool -check node -wingetId 'OpenJS.NodeJS.LTS' -hgName 'Node.js 20 LTS' -chocoName 'nodejs-lts'
Install-Tool -check python -wingetId 'Python.Python.311' -hgName 'Python 3.11' -chocoName 'python'

function Ensure-ModuleRepository {
    if (Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue) {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted | Out-Null
        return
    }
    Register-PSRepository -Name PSGallery `
        -SourceLocation 'https://www.powershellgallery.com/api/v2' `
        -ScriptSourceLocation 'https://www.powershellgallery.com/api/v2' `
        -PublishLocation 'https://www.powershellgallery.com/api/v2/package/' `
        -InstallationPolicy Trusted `
        -ErrorAction Stop | Out-Null
}

if (-not $SkipModuleBootstrap) {
    Write-Host '[provision] Installing PowerShell modules (Pester, ThreadJob) ...'
    Ensure-ModuleRepository
    pwsh -NoLogo -NoProfile -Command {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted | Out-Null
        Install-Module -Name Pester -RequiredVersion 6.0.0 -Scope CurrentUser -Force -AllowPrerelease -ErrorAction Stop | Out-Null
        Install-Module -Name ThreadJob -Scope CurrentUser -Force -ErrorAction Stop | Out-Null
    }
}

if ($SigningCertPath) {
    if (-not (Test-Path $SigningCertPath)) {
        Write-Warning "[provision] Signing certificate path $SigningCertPath not found; skipping import."
    } else {
        Write-Host "[provision] Importing signing certificate from $SigningCertPath"
        $securePwd = ConvertTo-SecureString $SigningCertPassword -AsPlainText -Force
        Import-PfxCertificate -FilePath $SigningCertPath -CertStoreLocation Cert:\CurrentUser\My -Password $securePwd | Out-Null
    }
}

Write-Host "[provision] Runner provisioning complete."
