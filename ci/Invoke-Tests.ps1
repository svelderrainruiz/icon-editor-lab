[CmdletBinding()]
param([int]$CoverageThreshold = 75)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Resolve-Path "$here/.."
New-Item -ItemType Directory -Force -Path "$root/TestResults" | Out-Null
$covFile = "$root/TestResults/coverage.xml"
$trxFile = "$root/TestResults/testResults.xml"
$ccPaths = @("$root/tools/*.ps1","$root/tools/**/*.ps1","$root/tools/**/*.psm1")
$cfg = New-PesterConfiguration
$cfg.Run.Path = "$root/tools/Tests"
$cfg.Run.PassThru = $true
$cfg.Run.Exit = $false
$cfg.CodeCoverage.Enabled = $true
$cfg.CodeCoverage.Path = $ccPaths
$cfg.CodeCoverage.OutputPath = $covFile
$cfg.CodeCoverage.OutputFormat = 'JaCoCo'
$cfg.TestResult.Enabled = $true
$cfg.TestResult.OutputPath = $trxFile
$res = Invoke-Pester -Configuration $cfg
$covered = try { [math]::Round($res.CodeCoverage.CoveredPercent,2) } catch { 0 }
Write-Host ("Coverage: {0}%  (threshold {1}%)" -f $covered, $CoverageThreshold)
if ($res.FailedCount -gt 0 -or $covered -lt $CoverageThreshold) {
  Write-Error "Gate failed."
  exit 1
}
Write-Host "Gate passed."
