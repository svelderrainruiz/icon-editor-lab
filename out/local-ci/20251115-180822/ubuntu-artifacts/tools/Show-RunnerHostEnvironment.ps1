#Requires -Version 7.0
[CmdletBinding()]
param(
    [string[]]$LibraryPaths
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
    $root = $env:WORKSPACE_ROOT
    if (-not $root) { $root = '/mnt/data/repo_local' }
    if (Test-Path -LiteralPath (Join-Path $root '.git')) {
        return (Resolve-Path -LiteralPath $root -ErrorAction Stop).ProviderPath
    }

    $fallback = Join-Path $PSScriptRoot '..'
    return (Resolve-Path -LiteralPath $fallback -ErrorAction Stop).ProviderPath
}

$repoRoot   = Get-RepoRoot
$modulePath = Join-Path $repoRoot 'src/tools/RunnerProfile.psm1'
if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
    Write-Error "RunnerProfile module not found at $modulePath"
    exit 1
}

Import-Module -Name $modulePath -Force -ErrorAction Stop

$envInfo = Get-RunnerHostEnvironment -LibraryPaths $LibraryPaths

$labelsText = ''
if ($envInfo.profile -and $envInfo.profile.PSObject.Properties.Name -contains 'labels' -and $envInfo.profile.labels) {
    $labelsText = [string]::Join(',', $envInfo.profile.labels)
}

$machine = $null
if ($envInfo.profile -and $envInfo.profile.PSObject.Properties.Name -contains 'machine') {
    $machine = $envInfo.profile.machine
}

$summary = "HostKind={0}; IsCI={1}; OS={2}; Machine={3}; DevModeSuggested={4}; DevModeSupported={5}" -f `
    $envInfo.hostKind, $envInfo.isCI, $envInfo.osFamily, $machine, $envInfo.devModeSuggested, $envInfo.devModeSupported

if ($labelsText) {
    $summary += "; Labels=$labelsText"
}

if ($envInfo.repoOwner -and $envInfo.repoName) {
    $summary += "; Repo={0}/{1}" -f $envInfo.repoOwner, $envInfo.repoName
}

$summary += "; PSEdition={0}; PSVersion={1}; PSHost={2}; PwshAvailable={3}" -f `
    $envInfo.psEdition, $envInfo.psVersion, $envInfo.psHostKind, $envInfo.pwshAvailable

Write-Host $summary
