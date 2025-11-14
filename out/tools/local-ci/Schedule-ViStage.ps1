[CmdletBinding()]
param(
    [string]$RepoRoot = (Get-Location).ProviderPath,
    [string]$RunRoot = (Join-Path $RepoRoot 'out/local-ci-ubuntu'),
    [string]$Stamp,
    [string]$SummaryPath,
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
if (-not $Stamp) {
    throw '[vi-scheduler] Stamp is required.'
}
if (-not $SummaryPath) {
    $SummaryPath = Join-Path (Join-Path $RunRoot $Stamp) 'vi-comparison/vi-comparison-summary.json'
}
if (-not (Test-Path -LiteralPath $SummaryPath)) {
    throw "[vi-scheduler] Summary not found at $SummaryPath"
}
$data = Get-Content -LiteralPath $SummaryPath -Raw | ConvertFrom-Json
$changed = @($data.pairs | Where-Object { $_.status -eq 'changed' -or $_.status -eq 'new' })
if ($changed.Count -eq 0) {
    Write-Host "[vi-scheduler] No VI differences detected for stamp $Stamp."
    return
}
Write-Host "[vi-scheduler] Detected $($changed.Count) VI differences for stamp $Stamp."
if ($DryRun) {
    Write-Host '[vi-scheduler] Dry run; not invoking renderer.'
    return
}
$cmd = "bash local-ci/ubuntu/invoke-local-ci.sh --only 45-vi-compare --only 40-package --skip 28-docs --skip 30-tests"
Write-Host "[vi-scheduler] Invoking: $cmd"
& bash local-ci/ubuntu/invoke-local-ci.sh --only 45-vi-compare --only 40-package --skip 28-docs --skip 30-tests
if ($LASTEXITCODE -ne 0) {
    throw '[vi-scheduler] Renderer returned non-zero exit code.'
}
