param(
    [string]$ResultsPath = (Join-Path $PSScriptRoot '..\artifacts\test-results'),
    [int]$CoverageThreshold = 75
)
$ErrorActionPreference = 'Stop'
$null = New-Item -ItemType Directory -Force -Path $ResultsPath
if (-not (Get-Module -ListAvailable -Name Pester)) {
    Install-Module Pester -Scope CurrentUser -Force -MinimumVersion 5.3.1
}
$moduleManifest = Join-Path $PSScriptRoot 'Tools.psd1'
$moduleRoot = Split-Path $moduleManifest -Parent
$coverageTargets = Get-ChildItem -Path $moduleRoot -Include *.ps1,*.psm1 -Recurse
$configuration = New-PesterConfiguration
$configuration.Run.Path = (Join-Path $PSScriptRoot '..\tests\tools')
$configuration.Run.PassThru = $true
$configuration.TestResult.Enabled = $true
$configuration.TestResult.OutputPath = Join-Path $ResultsPath 'pester-results.xml'
$configuration.CodeCoverage.Enabled = $true
$configuration.CodeCoverage.Path = $coverageTargets.FullName
$result = Invoke-Pester -Configuration $configuration
[int]$covered = [Math]::Round($result.CodeCoverage.NumberOfCommandsExecuted)
[int]$total   = [Math]::Round($result.CodeCoverage.NumberOfCommandsAnalyzed)
$percent = if ($total -gt 0) { [Math]::Round(($covered / $total) * 100) } else { 0 }
"`nCode Coverage: $covered / $total ($percent%)"
if ($percent -lt $CoverageThreshold) {
    Write-Error "Coverage $percent% is below threshold $CoverageThreshold%."
    exit 1
}
