#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$SupportedBitness = '64',
    [int]$MinimumSupportedLVVersion = 2023,
    [string]$LabVIEWMinorRevision = '0',
    [int]$Major = 0,
    [int]$Minor = 0,
    [int]$Patch = 0,
    [int]$Build = 0,
    [string]$Commit,
    [string]$ReleaseNotesFile,
    [string]$BuildToolchain = 'g-cli',
    [string]$BuildProvider,
    [string]$DisplayInformationJSON,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$AdditionalArguments
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$iconEditorRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$outputDir = Join-Path $iconEditorRoot 'Tooling\deployment'
if (-not (Test-Path -LiteralPath $outputDir -PathType Container)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$vipOutput = Join-Path $outputDir 'IconEditor_Stub.vip'
"vip-$SupportedBitness" | Set-Content -LiteralPath $vipOutput -Encoding utf8

if ($ReleaseNotesFile -and -not (Test-Path -LiteralPath $ReleaseNotesFile -PathType Leaf)) {
    New-Item -ItemType File -Path $ReleaseNotesFile -Force | Out-Null
}

Write-Host ("[build-vip] Stubbed VIP build for {0}-bit (LV {1}) using {2}." -f $SupportedBitness, $MinimumSupportedLVVersion, $BuildToolchain)
Write-Host ("[build-vip] Artifact created at {0}" -f $vipOutput)
