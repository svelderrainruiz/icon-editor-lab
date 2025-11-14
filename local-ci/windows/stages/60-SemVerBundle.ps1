#Requires -Version 7.0
param(
    [Parameter(Mandatory)]
    [pscustomobject]$Context
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = $Context.RepoRoot
$runRoot  = $Context.RunRoot
$timestamp = $Context.Timestamp

$exportScript = Join-Path $repoRoot 'tools' 'Export-SemverBundle.ps1'
$verifyScript = Join-Path $repoRoot 'tools' 'Verify-SemverBundle.ps1'

if (-not (Test-Path -LiteralPath $exportScript -PathType Leaf)) {
    throw "Export script not found at $exportScript"
}
if (-not (Test-Path -LiteralPath $verifyScript -PathType Leaf)) {
    throw "Verify script not found at $verifyScript"
}

$bundleRoot = Join-Path $runRoot ("semver-bundle-" + $timestamp)
if (Test-Path -LiteralPath $bundleRoot) {
    Remove-Item -LiteralPath $bundleRoot -Recurse -Force
}

Write-Host "[SemVerBundle] Exporting bundle to $bundleRoot"
try {
    & $exportScript -Destination $bundleRoot -IncludeWorkflow -GenerateIssueTemplate -Zip
} catch {
    Write-Error ("[SVB200] SemVer bundle export failed: {0}" -f $_.Exception.Message)
    throw
}

Write-Host "[SemVerBundle] Verifying bundle contents"
try {
    & $verifyScript -BundlePath $bundleRoot
} catch {
    Write-Error ("[SVB201] SemVer bundle verification failed: {0}" -f $_.Exception.Message)
    throw
}

$summaryScript = Join-Path $repoRoot 'tools' 'Write-SemverSummary.ps1'
if (-not (Test-Path -LiteralPath $summaryScript -PathType Leaf)) {
    throw "Summary script not found at $summaryScript"
}
try {
    & pwsh -NoLogo -NoProfile -File $summaryScript -BundleRoot $bundleRoot -WriteHost
} catch {
    Write-Error ("[SVB202] Failed to write SemVer summary: {0}" -f $_.Exception.Message)
    throw
}
