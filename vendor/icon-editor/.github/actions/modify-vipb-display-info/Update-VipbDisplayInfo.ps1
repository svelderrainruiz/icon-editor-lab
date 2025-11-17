#Requires -Version 7.0
[CmdletBinding()]
param(
    [int]$MinimumSupportedLVVersion,
    [string]$LabVIEWMinorRevision,
    [string]$SupportedBitness = '64',
    [int]$Major = 0,
    [int]$Minor = 0,
    [int]$Patch = 0,
    [int]$Build = 0,
    [string]$Commit,
    [string]$IconEditorRoot,
    [string]$VIPBPath,
    [string]$ReleaseNotesFile,
    [string]$DisplayInformationJSON
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$resolvedRoot = if ($IconEditorRoot) {
    (Resolve-Path -LiteralPath $IconEditorRoot -ErrorAction Stop).ProviderPath
} else {
    Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
}

$deploymentDir = Join-Path $resolvedRoot 'Tooling\deployment'
if (-not (Test-Path -LiteralPath $deploymentDir -PathType Container)) {
    New-Item -ItemType Directory -Path $deploymentDir -Force | Out-Null
}

$displayInfoPath = Join-Path $deploymentDir 'display-info.stub.json'
$DisplayInformationJSON | Set-Content -LiteralPath $displayInfoPath -Encoding utf8

if ($ReleaseNotesFile -and -not (Test-Path -LiteralPath $ReleaseNotesFile -PathType Leaf)) {
    New-Item -ItemType File -Path $ReleaseNotesFile -Force | Out-Null
}

Write-Host ("[update-vipb] Stubbed metadata update for LV {0} ({1}-bit)." -f $MinimumSupportedLVVersion, $SupportedBitness)
Write-Host ("[update-vipb] Display info captured at {0}" -f $displayInfoPath)
