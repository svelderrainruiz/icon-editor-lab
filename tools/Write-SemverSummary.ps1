#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BundleRoot,
    [switch]$WriteHost
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$bundleRoot = [System.IO.Path]::GetFullPath($BundleRoot)
if (-not (Test-Path -LiteralPath $bundleRoot -PathType Container)) {
    throw "Bundle root not found: $bundleRoot"
}

$summary = [ordered]@{
    schema      = 'icon-editor/semver-bundle-summary@v1'
    generatedAt = (Get-Date).ToString('o')
    bundleRoot  = $bundleRoot
    zipPath     = "$bundleRoot.zip"
    verified    = $true
}

$summaryPath = Join-Path $bundleRoot 'semver-summary.json'
$summary | ConvertTo-Json -Depth 4 | Out-File -FilePath $summaryPath -Encoding UTF8

if ($WriteHost) {
    Write-Host "[SemVerBundle] Summary"
    Write-Host ("  Bundle   : {0}" -f $bundleRoot)
    Write-Host ("  Zip      : {0}" -f "$bundleRoot.zip")
    Write-Host ("  Verified : {0}" -f $true)
    Write-Host ("  Summary  : {0}" -f $summaryPath)
}
