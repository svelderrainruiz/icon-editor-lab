#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$ManifestPath,
    [string]$RepoRoot,
    [string]$RunRoot,
    [string]$SignRoot,
    [switch]$SkipGitCheck,
    [switch]$NoExtract
)

$modulePath = Join-Path $PSScriptRoot 'Import-UbuntuRun.psm1'
Import-Module -Name $modulePath -Force
Invoke-UbuntuRunImport @PSBoundParameters | Out-Null
