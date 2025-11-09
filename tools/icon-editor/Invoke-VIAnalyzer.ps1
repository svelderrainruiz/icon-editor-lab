#Requires -Version 7.0
<#
.SYNOPSIS
Runs the LabVIEW VI Analyzer headlessly via LabVIEWCLI and captures telemetry.

.DESCRIPTION
Wraps the `RunVIAnalyzer` LabVIEWCLI operation so CI helpers can invoke VI
Analyzer without the GUI. Generates ASCII/HTML/RSL reports, optional `.rsl`
results files, and a JSON manifest summarising failures/broken VIs.

.PARAMETER ConfigPath
Path to the `.viancfg`, VI, folder, or LLB to analyze (required).

.PARAMETER OutputRoot
Root directory for analyzer artifacts. Each run creates a `<label>` subfolder
plus `latest-run.json`. Defaults to `tests/results/_agent/vi-analyzer`.

.PARAMETER Label
Optional label for this run. Defaults to `vi-analyzer-<timestamp>`.

.PARAMETER ReportSaveType
Report format (`ASCII`, `HTML`, or `RSL`). Defaults to `ASCII`.

.PARAMETER LabVIEWVersion
Version of LabVIEW to launch (only used when resolving LabVIEWCLI).

.PARAMETER Bitness
LabVIEW bitness (32 or 64) used when resolving LabVIEWCLI. Defaults to 32.

.PARAMETER LabVIEWCLIPath
Explicit path to `LabVIEWCLI.exe`. If omitted we resolve it via
`Resolve-LabVIEWCliPath`.

.PARAMETER CaptureResultsFile
When set, automatically writes a `.rsl` file to `<runDir>/vi-analyzer-results.rsl`
unless `-ResultsPath` was specified explicitly.

.PARAMETER ReportPath
Optional path for the human-readable report. Defaults to
`<runDir>/vi-analyzer-report.<ext>`.

.PARAMETER ResultsPath
Optional path for the `.rsl` results file. Requires `CaptureResultsFile` or
manual assignment.

.PARAMETER ConfigPassword
Password for encrypted `.viancfg` files, forwarded to LabVIEWCLI.

.PARAMETER ReportSort
Optional `VI` or `Test` sort order when the LabVIEW version supports it.

.PARAMETER ReportInclude
Optional list of result categories (`FAILED`,`PASSED`,`SKIPPED`) to include in
the report when supported.

.PARAMETER TimeoutSeconds
Maximum time to wait for LabVIEWCLI to finish (default 900s).

.PARAMETER AdditionalArguments
Extra arguments appended to the LabVIEWCLI invocation (after the analyzer args).

.PARAMETER PassThru
Return the telemetry object instead of just writing files.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ConfigPath,

  [string]$OutputRoot = 'tests/results/_agent/vi-analyzer',

  [string]$Label,

  [ValidateSet('ASCII','HTML','RSL')]
  [string]$ReportSaveType = 'ASCII',

  [int]$LabVIEWVersion = 2021,

  [ValidateSet(32, 64)]
  [int]$Bitness = 32,

  [string]$LabVIEWCLIPath,

  [switch]$CaptureResultsFile,

  [string]$ReportPath,

  [string]$ResultsPath,

  [int]$TimeoutSeconds = 900,

  [string[]]$AdditionalArguments,

  [string]$ConfigPassword,

  [ValidateSet('VI','Test')]
  [string]$ReportSort,

  [string[]]$ReportInclude,

  [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-ViAnalyzerFailureSummary {
  param(
    [Parameter(Mandatory)][psobject]$ResultObject,
    [string]$Prefix = '[vi-analyzer]'
  )
  $reportPath = $ResultObject.reportPath
  if ($reportPath) {
    Write-Host ("{0} VI Analyzer report: {1}" -f $Prefix, $reportPath) -ForegroundColor DarkGray
  }
  if ($ResultObject.summary) {
    $s = $ResultObject.summary
    Write-Host ("{0} Results: VIs={1}, Tests={2}, Passed={3}, Failed={4}, Skipped={5}" -f `
      $Prefix, $s.visAnalyzed, $s.totalTests, $s.passedTests, $s.failedTests, $s.skippedTests) -ForegroundColor DarkGray
    Write-Host ("{0} Errors: VI not loadable={1}, Test not loadable={2}, Test not runnable={3}, Test error out={4}" -f `
      $Prefix, $s.visNotLoadable, $s.testsNotLoadable, $s.testsNotRunnable, $s.testsErrorOut) -ForegroundColor DarkGray
  }
  if ($ResultObject.failedTestsByVi -and $ResultObject.failedTestsByVi.Count -gt 0) {
    Write-Host ("{0} Failed Tests (sorted by VI):" -f $Prefix) -ForegroundColor Yellow
    foreach ($group in $ResultObject.failedTestsByVi) {
      Write-Host ("{0}   {1} ({2})" -f $Prefix, $group.viName, $group.viPath) -ForegroundColor Yellow
      foreach ($test in $group.tests) {
        Write-Host ("{0}     {1}`t{2}" -f $Prefix, $test.test, $test.details) -ForegroundColor Yellow
      }
      Write-Host ("{0}" -f $Prefix) -ForegroundColor Yellow
    }
  }
  $failures = @()
  if ($ResultObject.failures) {
    $failures = $ResultObject.failures | Where-Object { $_ } | Select-Object -First 5
  }
  if ($failures.Count -gt 0) {
    Write-Host ("{0} Top failed tests:" -f $Prefix) -ForegroundColor Yellow
    foreach ($entry in $failures) {
      Write-Host ("{0}   {1} :: {2} :: {3}" -f $Prefix, $entry.vi, $entry.test, $entry.details) -ForegroundColor Yellow
    }
    if ($ResultObject.failureCount -gt $failures.Count) {
      Write-Host ("{0}   ... {1} additional failures" -f $Prefix, ($ResultObject.failureCount - $failures.Count)) -ForegroundColor Yellow
    }
  }
  if ($ResultObject.cliLogPath -and (Test-Path -LiteralPath $ResultObject.cliLogPath -PathType Leaf)) {
    Write-Host ("{0} Analyzer CLI log tail:" -f $Prefix) -ForegroundColor DarkGray
    Get-Content -LiteralPath $ResultObject.cliLogPath -Tail 15 | ForEach-Object {
      Write-Host ("{0}   {1}" -f $Prefix, $_.TrimEnd()) -ForegroundColor DarkGray
    }
  }
}

function Ensure-VendorTools {
  if (Get-Command -Name Resolve-LabVIEWCliPath -ErrorAction SilentlyContinue) { return }
  $modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'VendorTools.psm1'
  if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
    throw "Vendor tools module not found at '$modulePath'."
  }
  Import-Module $modulePath -Force
}

Ensure-VendorTools

function Resolve-RepoRoot {
  param([string]$StartPath = (Get-Location).Path)
  try {
    $root = git -C $StartPath rev-parse --show-toplevel 2>$null
    if ($root) {
      return (Resolve-Path -LiteralPath $root.Trim()).Path
    }
  } catch {}
  return (Resolve-Path -LiteralPath $StartPath).Path
}

$repoRoot = Resolve-RepoRoot
$structuredConfigInfo = $null
$originalConfigPath = $ConfigPath
if (Test-Path -LiteralPath $ConfigPath -PathType Leaf) {
  try {
    $rawContent = Get-Content -LiteralPath $ConfigPath -Raw -ErrorAction Stop
    if ($rawContent.TrimStart().StartsWith('{')) {
      $parsed = $rawContent | ConvertFrom-Json -ErrorAction Stop
      if ($parsed.schema -and $parsed.schema -like 'vi-analyzer/config*') {
        $targetPath = $parsed.targetPath
        if (-not [string]::IsNullOrWhiteSpace($targetPath)) {
          if (-not [System.IO.Path]::IsPathRooted($targetPath)) {
            $targetPath = Join-Path $repoRoot $targetPath
          }
          $ConfigPath = $targetPath
          $structuredConfigInfo = [ordered]@{
            sourcePath = (Resolve-Path -LiteralPath $originalConfigPath -ErrorAction Stop).Path
            targetPath = (Resolve-Path -LiteralPath $targetPath -ErrorAction Stop).Path
            targetType = if ($parsed.targetType) { $parsed.targetType } else { 'folder' }
          }
        }
      }
    }
  } catch {
    Write-Warning ("Failed to parse structured VI Analyzer config '{0}': {1}" -f $ConfigPath, $_.Exception.Message)
  }
}

$configResolved = Resolve-Path -LiteralPath $ConfigPath -ErrorAction Stop
$configResolved = $configResolved.Path
$configSourceResolved = $null
try {
  $configSourceResolved = (Resolve-Path -LiteralPath $originalConfigPath -ErrorAction Stop).Path
} catch {}
if ($structuredConfigInfo -and $structuredConfigInfo.sourcePath) {
  $configSourceResolved = $structuredConfigInfo.sourcePath
}

if (-not $LabVIEWCLIPath) {
  $LabVIEWCLIPath = Resolve-LabVIEWCliPath -Version $LabVIEWVersion -Bitness $Bitness
}
if (-not $LabVIEWCLIPath) {
  throw "Unable to resolve LabVIEWCLI.exe for version $LabVIEWVersion ($Bitness-bit)."
}
$cliResolved = Resolve-Path -LiteralPath $LabVIEWCLIPath -ErrorAction Stop
$cliResolved = $cliResolved.Path

$portNumber = $null
$labviewExePath = $null
if (Get-Command -Name Find-LabVIEWVersionExePath -ErrorAction SilentlyContinue) {
  try {
    $labviewExePath = Find-LabVIEWVersionExePath -Version $LabVIEWVersion -Bitness $Bitness
  } catch {
    $labviewExePath = $null
  }
}
if ($labviewExePath) {
  try {
    $iniPath = Get-LabVIEWIniPath -LabVIEWExePath $labviewExePath
    if ($iniPath -and (Test-Path -LiteralPath $iniPath -PathType Leaf)) {
      $enabledValue = $null
      try { $enabledValue = Get-LabVIEWIniValue -LabVIEWExePath $labviewExePath -LabVIEWIniPath $iniPath -Key 'server.tcp.enabled' } catch {}
      if ($enabledValue -and $enabledValue.Trim().ToLowerInvariant() -notin @('1','true')) {
        Write-Warning ("VI Analyzer: LabVIEW VI Server appears disabled in {0} (server.tcp.enabled={1}). CLI connections may fail." -f $iniPath, $enabledValue)
      }
      $portValue = $null
      try { $portValue = Get-LabVIEWIniValue -LabVIEWExePath $labviewExePath -LabVIEWIniPath $iniPath -Key 'server.tcp.port' } catch {}
      if ($portValue) {
        $parsedPort = 0
        if ([int]::TryParse($portValue.Trim(), [ref]$parsedPort) -and $parsedPort -gt 0) {
          $portNumber = $parsedPort
        }
      }
    }
  } catch {
    Write-Verbose ("VI Analyzer: Failed to inspect LabVIEW.ini for VI Server port: {0}" -f $_.Exception.Message)
  }
}

$outputRootResolved = if ([System.IO.Path]::IsPathRooted($OutputRoot)) {
  $OutputRoot
} else {
  Join-Path (Resolve-Path .).Path $OutputRoot
}
if (-not (Test-Path -LiteralPath $outputRootResolved -PathType Container)) {
  [void](New-Item -ItemType Directory -Path $outputRootResolved -Force)
}

if (-not $Label) {
  $Label = "vi-analyzer-{0}" -f (Get-Date -Format 'yyyyMMddTHHmmss')
}
$runDir = Join-Path $outputRootResolved $Label
if (Test-Path -LiteralPath $runDir -PathType Container) {
  Remove-Item -LiteralPath $runDir -Recurse -Force -ErrorAction SilentlyContinue
}
[void](New-Item -ItemType Directory -Path $runDir -Force)

$reportExtension = '.txt'
switch ($ReportSaveType) {
  'HTML' { $reportExtension = '.html' }
  'RSL'  { $reportExtension = '.rsl' }
}
if (-not $ReportPath) {
  $ReportPath = Join-Path $runDir ("vi-analyzer-report{0}" -f $reportExtension)
}
$reportResolved = [System.IO.Path]::GetFullPath($ReportPath)

if ($CaptureResultsFile -and -not $ResultsPath) {
  $ResultsPath = Join-Path $runDir 'vi-analyzer-results.rsl'
}
if ($ResultsPath) {
  $ResultsPath = [System.IO.Path]::GetFullPath($ResultsPath)
}

$argumentList = New-Object System.Collections.Generic.List[string]
if ($AdditionalArguments) {
  foreach ($arg in $AdditionalArguments) { $argumentList.Add($arg) }
}
if ($portNumber -and -not ($argumentList -contains '-PortNumber')) {
  $argumentList.Add('-PortNumber')
  $argumentList.Add([string]$portNumber)
}
if ($labviewExePath -and -not ($argumentList -contains '-LabVIEWPath')) {
  $argumentList.Add('-LabVIEWPath')
  $argumentList.Add($labviewExePath)
}
$argumentList.Add('-OperationName')
$argumentList.Add('RunVIAnalyzer')
$argumentList.Add('-ConfigPath')
$argumentList.Add($configResolved)
$argumentList.Add('-ReportPath')
$argumentList.Add($reportResolved)
$argumentList.Add('-ReportSaveType')
$argumentList.Add($ReportSaveType)
if ($ConfigPassword) {
  $argumentList.Add('-ConfigPassword')
  $argumentList.Add($ConfigPassword)
}
if ($ReportSort) {
  $argumentList.Add('-ReportSort')
  $argumentList.Add($ReportSort)
}
if ($ReportInclude) {
  foreach ($include in $ReportInclude) {
    if (-not [string]::IsNullOrWhiteSpace($include)) {
      $argumentList.Add('-ReportInclude')
      $argumentList.Add($include)
    }
  }
}
if ($ResultsPath) {
  $argumentList.Add('-ResultsPath')
  $argumentList.Add($ResultsPath)
}

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $cliResolved
foreach ($arg in $argumentList) {
  [void]$psi.ArgumentList.Add($arg)
}
$psi.WorkingDirectory = Split-Path $configResolved -Parent
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true

$process = [System.Diagnostics.Process]::Start($psi)
if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
  try { $process.Kill() } catch {}
  throw "VI Analyzer invocation timed out after $TimeoutSeconds seconds."
}
$stdOut = $process.StandardOutput.ReadToEnd()
$stdErr = $process.StandardError.ReadToEnd()
$exitCode = $process.ExitCode

$cliLogPath = Join-Path $runDir 'vi-analyzer-cli.log'
$cliLogContent = @(
  "Command: `"$cliResolved`" $($argumentList -join ' ')",
  '',
  '--- stdout ---',
  $stdOut,
  '',
  '--- stderr ---',
  $stdErr
)
Set-Content -LiteralPath $cliLogPath -Value $cliLogContent -Encoding utf8

$testFailureExitCode = 0
$testFailureExitCodes = @(3)
if ($exitCode -ne 0) {
  if ($exitCode -lt 0) {
    $errorMessage = "VI Analyzer failed (exit code $exitCode). See $cliLogPath for details."
    switch ($exitCode) {
      14217 { $errorMessage += ' (project-based analyzer configs are not supported by LabVIEWCLI.)' }
      1003  { $errorMessage += ' (VI Analyzer reported a non-executable VI.)' }
      default {
        $errorMessage += ' (LabVIEW CLI reported an internal failure.)'
      }
    }
    throw $errorMessage
  } elseif ($testFailureExitCodes -contains $exitCode) {
    Write-Warning ("VI Analyzer completed with test failures (exit code {0}). See {1} for details." -f $exitCode, $cliLogPath)
    $testFailureExitCode = $exitCode
  } else {
    $errorMessage = "VI Analyzer failed (exit code $exitCode). See $cliLogPath for details."
    switch ($exitCode) {
      14217 { $errorMessage += ' (project-based analyzer configs are not supported by LabVIEWCLI.)' }
      1003  { $errorMessage += ' (VI Analyzer reported a non-executable VI.)' }
      default {
        $errorMessage += ' (LabVIEW CLI reported an internal failure.)'
      }
    }
    throw $errorMessage
  }
}

if (-not (Test-Path -LiteralPath $reportResolved -PathType Leaf)) {
  throw "VI Analyzer report not found at '$reportResolved'."
}

$reportLines = Get-Content -LiteralPath $reportResolved
$currentVi = $null
$currentCategory = $null
$brokenEntries = New-Object System.Collections.Generic.List[object]
$failureEntries = New-Object System.Collections.Generic.List[object]
$versionMismatchEntries = New-Object System.Collections.Generic.List[object]
$failedTestsByVi = @{}
$inFailedTestsSection = $false
$groupViName = $null
$groupViPath = $null
$summaryFieldMap = [ordered]@{
  'VIs Analyzed'    = 'visAnalyzed'
  'Total Tests Run' = 'totalTests'
  'Passed Tests'    = 'passedTests'
  'Failed Tests'    = 'failedTests'
  'Skipped Tests'   = 'skippedTests'
  'VI not loadable'    = 'visNotLoadable'
  'Test not loadable'  = 'testsNotLoadable'
  'Test not runnable'  = 'testsNotRunnable'
  'Test error out'     = 'testsErrorOut'
}
$summaryValues = @{}
foreach ($key in $summaryFieldMap.Values) { $summaryValues[$key] = $null }

foreach ($line in $reportLines) {
  $trimmed = $line.Trim()
  if ($trimmed -eq 'Failed Tests (sorted by VI)') {
    $inFailedTestsSection = $true
    $groupViName = $null
    $groupViPath = $null
    continue
  }
  $summaryMatch = [regex]::Match($line, '^(?<label>[A-Za-z ]+)\t(?<value>-?\d+)$')
  if ($summaryMatch.Success) {
    $label = $summaryMatch.Groups['label'].Value.Trim()
    if ($summaryFieldMap.Contains($label)) {
      $summaryValues[$summaryFieldMap[$label]] = [int]$summaryMatch.Groups['value'].Value
      continue
    }
  }
  if ($inFailedTestsSection) {
    if ([string]::IsNullOrWhiteSpace($line)) {
      $groupViName = $null
      $groupViPath = $null
      continue
    }
    $headerMatch = [regex]::Match($line, '^(?<vi>.+?) \((?<path>[A-Za-z]:\\.+)\)$')
    if ($headerMatch.Success) {
      $groupViName = $headerMatch.Groups['vi'].Value.Trim()
      $groupViPath = $headerMatch.Groups['path'].Value.Trim()
      if (-not $failedTestsByVi.ContainsKey($groupViName)) {
        $failedTestsByVi[$groupViName] = [ordered]@{
          viName = $groupViName
          viPath = $groupViPath
          tests  = New-Object System.Collections.Generic.List[object]
        }
      }
      continue
    }
    $testLineMatch = [regex]::Match($line, '^(?<test>[^\t]+)\t(?<details>.+)$')
    if ($testLineMatch.Success -and $groupViName -and $failedTestsByVi.ContainsKey($groupViName)) {
      $entry = [pscustomobject]@{
        test    = $testLineMatch.Groups['test'].Value.Trim()
        details = $testLineMatch.Groups['details'].Value.Trim()
        vi      = $groupViName
        path    = $groupViPath
      }
      $failedTestsByVi[$groupViName].tests.Add($entry) | Out-Null
      continue
    }
  }
  $viMatch = [regex]::Match($trimmed, '^VI:\s+"(.+)"')
  if ($viMatch.Success) {
    $currentVi = $viMatch.Groups[1].Value
    continue
  }
  $categoryMatch = [regex]::Match($trimmed, '^Category:\s+\*\*(.+?)\*\*')
  if ($categoryMatch.Success) {
    $currentCategory = $categoryMatch.Groups[1].Value
    continue
  }
  $versionMismatchMatch = [regex]::Match($trimmed, '^(?<vi>[^\t]+\.vi)\s+(?<path>[A-Za-z]:\\.+?)\s+Error\s+1125')
  if ($versionMismatchMatch.Success -and ($trimmed -match 'saved in a LabVIEW version newer')) {
    $entry = [pscustomobject]@{
      vi              = $versionMismatchMatch.Groups['vi'].Value
      path            = $versionMismatchMatch.Groups['path'].Value
      analyzerVersion = $LabVIEWVersion
      analyzerBitness = $Bitness
      details         = $trimmed
    }
    $versionMismatchEntries.Add($entry) | Out-Null
  }
  $testMatch = [regex]::Match($trimmed, '^\-\s+\*\*(.+?)\*\*\s+\-\s+(FAILED|PASSED)\.?\s*(.*)$')
  if ($testMatch.Success) {
    $testName = $testMatch.Groups[1].Value
    $status = $testMatch.Groups[2].Value
    $details = $testMatch.Groups[3].Value
    if ($status -eq 'FAILED') {
      $entry = [pscustomobject]@{
        vi       = $currentVi
        category = $currentCategory
        test     = $testName
        details  = $details
      }
      $failureEntries.Add($entry) | Out-Null
      if ($testName -eq 'Broken VI' -or $details -like '*cannot run*') {
        $brokenEntries.Add($entry) | Out-Null
      }
    }
  }
}

$timestamp = (Get-Date).ToString('o')
$brokenNames = @($brokenEntries | ForEach-Object { $_.vi } | Where-Object { $_ } | Sort-Object -Unique)

$resultObject = [ordered]@{
  schema          = 'icon-editor/vi-analyzer@v1'
  label           = $Label
  configPath      = $configResolved
  configSourcePath = $configSourceResolved
  reportPath      = $reportResolved
  reportFormat    = $ReportSaveType
  resultsPath     = $ResultsPath
  runDir          = $runDir
  outputRoot      = $outputRootResolved
  cliPath         = $cliResolved
  exitCode        = $exitCode
  labviewVersion  = $LabVIEWVersion
  bitness         = $Bitness
  timestamp       = $timestamp
  brokenViCount   = $brokenEntries.Count
  brokenViNames   = $brokenNames
  failureCount    = $failureEntries.Count
  brokenVis       = $brokenEntries
  failures        = $failureEntries
  analyzerExitCode = $exitCode
  testFailureExitCode = $testFailureExitCode
  versionMismatchCount = $versionMismatchEntries.Count
  versionMismatches    = $versionMismatchEntries
  stdout          = $stdOut
  stderr          = $stdErr
  cliLogPath      = $cliLogPath
  failedTestsByVi = $failedTestsByVi.Values
  summary         = $summaryValues
  summaryPrinted  = $false
  devModeLikelyDisabled = $false
}

$resultJsonPath = Join-Path $runDir 'vi-analyzer.json'
$resultObject | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $resultJsonPath -Encoding utf8

$latestPointerPath = Join-Path $outputRootResolved 'latest-run.json'
$pointer = @{
  label      = $Label
  reportPath = $reportResolved
  resultsPath = $ResultsPath
  runPath    = $runDir
  updatedAt  = $timestamp
}
$pointer | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $latestPointerPath -Encoding utf8

$resultPsObject = [pscustomobject]$resultObject
$hasGroupFailures = $false
if ($resultPsObject.failedTestsByVi) {
  $hasGroupFailures = (($resultPsObject.failedTestsByVi | ForEach-Object { $_.tests.Count } | Measure-Object -Sum).Sum -gt 0)
}
if ($testFailureExitCode -gt 0 -and ($failureEntries.Count -gt 0 -or $hasGroupFailures)) {
  Write-ViAnalyzerFailureSummary -ResultObject $resultPsObject -Prefix '[vi-analyzer]'
  $resultObject.summaryPrinted = $true
  $resultPsObject.summaryPrinted = $true
  $devModeHint = $false
  if ($resultPsObject.failedTestsByVi) {
    foreach ($group in $resultPsObject.failedTestsByVi) {
      if ($group.viName -eq 'MissingInProjectCLI.vi') {
        $devModeHint = $true
        break
      }
    }
  }
  if ($devModeHint) {
    $resultObject.devModeLikelyDisabled = $true
    $resultPsObject.devModeLikelyDisabled = $true
  }
  $resultObject | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $resultJsonPath -Encoding utf8
  if ($testFailureExitCode -eq 3) {
    $closeScript = Join-Path $repoRoot 'tools' 'Close-LabVIEW.ps1'
    if ($labviewExePath -and (Test-Path -LiteralPath $closeScript -PathType Leaf)) {
      try { & $closeScript -LabVIEWExePath $labviewExePath -Provider 'labviewcli' | Out-Null } catch { Write-Warning ("Failed to close LabVIEW after analyzer failure: {0}" -f $_.Exception.Message) }
    }
    $message = "VI Analyzer reported failed tests (exit code $testFailureExitCode). Run stopped."
    if ($devModeHint) {
      $message += " MissingInProjectCLI.vi failures were detected, which usually means development mode is disabled. Re-run tools/icon-editor/Enable-DevMode.ps1 for the target LabVIEW version and retry."
    }
    throw $message
  }
}

if ($PassThru) {
  return $resultPsObject
}
