#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$Root = 'out/semver-bundle'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$rootPath = [System.IO.Path]::GetFullPath($Root)
if (-not (Test-Path -LiteralPath $rootPath -PathType Container)) {
    throw "[SVB300] No SemVer bundles found under $rootPath"
}

$bundle = Get-ChildItem -LiteralPath $rootPath -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $bundle) {
    throw "[SVB300] No SemVer bundles found under $rootPath"
}

$summaryPath = Join-Path $bundle.FullName 'semver-summary.json'
$summary = $null
if (Test-Path -LiteralPath $summaryPath -PathType Leaf) {
    try {
        $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Warning ("[SVB202] Failed to read summary JSON: {0}" -f $_.Exception.Message)
    }
}

[pscustomobject]@{
    BundleRoot = $bundle.FullName
    ZipPath    = "$($bundle.FullName).zip"
    Summary    = $summary
}
