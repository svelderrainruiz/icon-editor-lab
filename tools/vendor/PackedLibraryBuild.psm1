#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$targetModule = Join-Path $repoRoot 'src' 'tools' 'vendor' 'PackedLibraryBuild.psm1'
if (-not (Test-Path -LiteralPath $targetModule -PathType Leaf)) {
    throw "PackedLibraryBuild module not found at '$targetModule'."
}

Import-Module -Name $targetModule -Force -Global | Out-Null
