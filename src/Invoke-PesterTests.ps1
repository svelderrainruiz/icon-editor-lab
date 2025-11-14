#Requires -Version 7.0
[CmdletBinding()]
param(
  [string]$TestsPath = 'tests',
  [string]$ResultsPath = 'tests/results',
  [ValidateSet('include','exclude','only','auto')][string]$IntegrationMode = 'include',
  [switch]$IncludeIntegration,
  [string[]]$IncludePatterns,
[string[]]$ExcludePatterns,
[switch]$EmitFailuresJsonAlways,
[string[]]$Tags,
[string[]]$ExcludeTags,
[string]$Tag,
[string]$ExcludeTag,
[string]$LogFile = 'pester-dispatcher.log',
[string]$SummaryJson = 'pester-summary.json',
[string]$SummaryText = 'pester-summary.txt',
[string]$FailuresJson = 'pester-failures.json',
  [switch]$Quiet,
  [switch]$CleanLabVIEW,
  [switch]$CleanAfter,
  [switch]$DetectLeaks,
  [switch]$KillLeaks,
  [switch]$FailOnLeaks,
  [int]$LeakGraceSeconds = 5
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSModuleAutoLoadingPreference = 'None'
Import-Module Microsoft.PowerShell.Management -ErrorAction Stop
Import-Module Microsoft.PowerShell.Utility -ErrorAction Stop
Import-Module Microsoft.PowerShell.Host -ErrorAction Stop

if ($Tag) { $Tags = @($Tags) + $Tag }
if ($ExcludeTag) { $ExcludeTags = @($ExcludeTags) + $ExcludeTag }

function Resolve-AutoIntegrationPreference {
  param([bool]$Default = $true)

  $envPriority = @(
    @{ Name='INCLUDE_INTEGRATION';        Label='env:INCLUDE_INTEGRATION' },
    @{ Name='INPUT_INCLUDE_INTEGRATION'; Label='env:INPUT_INCLUDE_INTEGRATION' },
    @{ Name='GITHUB_INPUT_INCLUDE_INTEGRATION'; Label='env:GITHUB_INPUT_INCLUDE_INTEGRATION' },
    @{ Name='EV_INCLUDE_INTEGRATION';    Label='env:EV_INCLUDE_INTEGRATION' },
    @{ Name='CI_INCLUDE_INTEGRATION';    Label='env:CI_INCLUDE_INTEGRATION' },
    @{ Name='GH_INCLUDE_INTEGRATION';    Label='env:GH_INCLUDE_INTEGRATION' },
    @{ Name='include_integration';       Label='env:include_integration' }
  )

  foreach ($entry in $envPriority) {
    try {
      $raw = [System.Environment]::GetEnvironmentVariable($entry.Name)
    } catch {
      continue
    }
    if ([string]::IsNullOrWhiteSpace($raw)) { continue }
    $parsed = $null
    switch ($raw.Trim().ToLowerInvariant()) {
      'true' { $parsed = $true }
      'false' { $parsed = $false }
      '1' { $parsed = $true }
      '0' { $parsed = $false }
      'yes' { $parsed = $true }
      'no' { $parsed = $false }
      'on' { $parsed = $true }
      'off' { $parsed = $false }
    }
    if ($null -ne $parsed) {
      return [pscustomobject]@{
        Include = [bool]$parsed
        Source  = ("{0}={1}" -f $entry.Label,$raw)
      }
    }
  }

  return [pscustomobject]@{
    Include = [bool]$Default
    Source  = 'default:auto'
  }
}

function Resolve-IntegrationDecision {
  param([ValidateSet('include','exclude','only','auto')][string]$Mode)

  switch ($Mode) {
    'include' {
      return [pscustomobject]@{
        Mode        = 'include'
        Include     = $true
        Reason      = 'mode:include'
        TagFilter   = $null
        ExcludeTags = @()
      }
    }
    'exclude' {
      return [pscustomobject]@{
        Mode        = 'exclude'
        Include     = $false
        Reason      = 'mode:exclude'
        TagFilter   = $null
        ExcludeTags = @('Integration')
      }
    }
    'only' {
      return [pscustomobject]@{
        Mode        = 'only'
        Include     = $true
        Reason      = 'mode:only'
        TagFilter   = @('Integration')
        ExcludeTags = @()
      }
    }
    'auto' {
      $auto = Resolve-AutoIntegrationPreference -Default:$true
      if ($auto.Include) {
        return [pscustomobject]@{
          Mode        = 'include'
          Include     = $true
          Reason      = "auto:$($auto.Source)"
          TagFilter   = $null
          ExcludeTags = @()
        }
      } else {
        return [pscustomobject]@{
          Mode        = 'exclude'
          Include     = $false
          Reason      = "auto:$($auto.Source)"
          TagFilter   = $null
          ExcludeTags = @('Integration')
        }
      }
    }
  }
}

function Ensure-PesterModule {
  param([string]$RequiredVersion = '5.7.1')

  $module = Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -eq [version]$RequiredVersion } | Select-Object -First 1
  if ($module) {
    Import-Module Pester -RequiredVersion $RequiredVersion -Force
    return
  }

  Write-Host ("[dispatcher] Installing Pester {0} locally..." -f $RequiredVersion) -ForegroundColor DarkGray
  $toolsModules = Join-Path (Split-Path -Parent $PSCommandPath) 'tools/modules'
  if (-not (Test-Path -LiteralPath $toolsModules)) {
    New-Item -ItemType Directory -Path $toolsModules -Force | Out-Null
  }
  Save-Module -Name Pester -RequiredVersion $RequiredVersion -Path $toolsModules -Force
  $importTarget = Get-ChildItem -Path (Join-Path $toolsModules 'Pester') -Directory | Where-Object { $_.Name -eq $RequiredVersion } | Select-Object -First 1
  if (-not $importTarget) {
    $importTarget = Get-ChildItem -Path (Join-Path $toolsModules 'Pester') -Directory | Sort-Object Name -Descending | Select-Object -First 1
  }
  Import-Module (Join-Path $importTarget.FullName 'Pester.psd1') -Force
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$testsFull = Resolve-Path -LiteralPath (Join-Path $repoRoot $TestsPath) -ErrorAction Stop
$resultsFull = Join-Path $repoRoot $ResultsPath
if (-not (Test-Path -LiteralPath $resultsFull -PathType Container)) {
  New-Item -ItemType Directory -Path $resultsFull -Force | Out-Null
}

$logPath = Join-Path $resultsFull $LogFile
$summaryJsonPath = Join-Path $resultsFull $SummaryJson
$summaryTextPath = Join-Path $resultsFull $SummaryText
$failuresJsonPath = Join-Path $resultsFull $FailuresJson

$dispatcherModule = Join-Path $repoRoot 'tools/Dispatcher/TestSelection.psm1'
if (Test-Path -LiteralPath $dispatcherModule -PathType Leaf) {
  Import-Module $dispatcherModule -Force
}

$testsIsFile = (Test-Path -LiteralPath $testsFull -PathType Leaf)
$selectedTargets = @()

if ($testsIsFile) {
  $selectedTargets = @($testsFull)
} else {
  $allTests = @(Get-ChildItem -LiteralPath $testsFull -Recurse -Include *.Tests.ps1)
  if (-not $allTests -or $allTests.Count -eq 0) {
    Write-Warning ("[dispatcher] No '*.Tests.ps1' files found under {0}" -f $testsFull)
    exit 0
  }

  if (($IncludePatterns -and $IncludePatterns.Count -gt 0) -or ($ExcludePatterns -and $ExcludePatterns.Count -gt 0)) {
    if (Get-Command Invoke-DispatcherIncludeExcludeFilter -ErrorAction SilentlyContinue) {
      $filterResult = Invoke-DispatcherIncludeExcludeFilter -Files $allTests -IncludePatterns $IncludePatterns -ExcludePatterns $ExcludePatterns
      $selectedTargets = @($filterResult.Files)
    } else {
      $selectedTargets = @($allTests)
      if ($IncludePatterns) {
        $selectedTargets = @($selectedTargets | Where-Object {
          $match = $false
          foreach ($pattern in $IncludePatterns) {
            if (-not $pattern) { continue }
            if ($_.FullName -like $pattern -or $_.Name -like $pattern) { $match = $true; break }
          }
          $match
        })
      }
      if ($ExcludePatterns) {
        $selectedTargets = @($selectedTargets | Where-Object {
          $exclude = $false
          foreach ($pattern in $ExcludePatterns) {
            if (-not $pattern) { continue }
            if ($_.FullName -like $pattern -or $_.Name -like $pattern) { $exclude = $true; break }
          }
          -not $exclude
        })
      }
    }
  } else {
    $selectedTargets = $allTests
  }

  if (-not $selectedTargets -or $selectedTargets.Count -eq 0) {
    Write-Warning "[dispatcher] No test files matched the provided filters."
    exit 0
  }

  if ($selectedTargets.Count -eq $allTests.Count -and -not $IncludePatterns -and -not $ExcludePatterns) {
    $selectedTargets = @($testsFull)
  } else {
    $selectedTargets = @($selectedTargets | Select-Object -ExpandProperty FullName)
  }
}

$modeProvided = $PSBoundParameters.ContainsKey('IntegrationMode')
if ($IncludeIntegration.IsPresent -and -not $modeProvided) {
  $IntegrationMode = 'include'
}
$integrationDecision = Resolve-IntegrationDecision -Mode $IntegrationMode

Write-Host ("[dispatcher] TestsPath: {0}" -f $testsFull) -ForegroundColor Gray
Write-Host ("[dispatcher] ResultsPath: {0}" -f $resultsFull) -ForegroundColor Gray
Write-Host ("[dispatcher] Selected targets: {0}" -f ($selectedTargets -join ', ')) -ForegroundColor DarkGray
Write-Host ("[dispatcher] Integration mode: requested={0} applied={1} include={2} reason={3}" -f $IntegrationMode, $integrationDecision.Mode, $integrationDecision.Include, $integrationDecision.Reason) -ForegroundColor DarkCyan

Ensure-PesterModule

$conf = New-PesterConfiguration
$conf.Run.Path = $selectedTargets
$conf.Run.PassThru = $true
$conf.Output.Verbosity = if ($Quiet) { 'Normal' } else { 'Detailed' }
$conf.TestResult.Enabled = $true
$conf.TestResult.OutputFormat = 'NUnitXml'
$conf.TestResult.OutputPath = Join-Path $resultsFull 'pester-results.xml'

$tagFilters = @()
if ($integrationDecision.TagFilter) { $tagFilters += $integrationDecision.TagFilter }
if ($Tags) { $tagFilters += $Tags }
$tagFilters = @($tagFilters | Where-Object { $_ } | Select-Object -Unique)
if ($tagFilters.Count -gt 0) {
  $conf.Filter.Tag = $tagFilters
}

$excludeFilters = @()
if ($integrationDecision.ExcludeTags) { $excludeFilters += $integrationDecision.ExcludeTags }
if ($ExcludeTags) { $excludeFilters += $ExcludeTags }
$excludeFilters = @($excludeFilters | Where-Object { $_ } | Select-Object -Unique)
if ($excludeFilters.Count -gt 0) {
  $conf.Filter.ExcludeTag = $excludeFilters
}

if ($IncludePatterns -and $IncludePatterns.Count -gt 0 -and $selectedTargets -eq @($testsFull)) {
  $conf.Filter.ScriptBlock = {
    param($script, $suite)
    $file = $script.File
    foreach ($pattern in $IncludePatterns) {
      if (-not $pattern) { continue }
      if ($file -like $pattern -or (Split-Path -Leaf $file) -like $pattern) { return $true }
    }
    return $false
  }
}

Start-Transcript -Path $logPath -Force | Out-Null
try {
  $pesterRun = Invoke-Pester -Configuration $conf
} finally {
  Stop-Transcript | Out-Null
}

$total = $pesterRun.TotalCount
$passed = $pesterRun.PassedCount
$failed = $pesterRun.FailedCount
$skipped = $pesterRun.SkippedCount
$errors = $pesterRun.InconclusiveCount
$durationSeconds = [Math]::Round($pesterRun.Duration.TotalSeconds, 3)

$summaryLines = @(
  "Tests Passed: $passed",
  "Tests Failed: $failed",
  "Tests Skipped: $skipped",
  "Duration (s): $durationSeconds"
)
$summaryLines | Set-Content -LiteralPath $summaryTextPath -Encoding utf8

$summaryPayload = [ordered]@{
  schemaVersion    = 'pester-summary/v1'
  generatedAt      = (Get-Date).ToUniversalTime().ToString('o')
  result           = if ($failed -gt 0 -or $errors -gt 0) { 'failed' } else { 'passed' }
  totals           = [ordered]@{
    tests   = $total
    passed  = $passed
    failed  = $failed
    errors  = $errors
    skipped = $skipped
  }
  duration_s       = $durationSeconds
  integration      = [ordered]@{
    requestedMode       = $IntegrationMode
    appliedMode         = $integrationDecision.Mode
    includeIntegration  = $integrationDecision.Include
    reason              = $integrationDecision.Reason
  }
  filters          = [ordered]@{
    includePatterns = $IncludePatterns
    excludePatterns = $ExcludePatterns
    tags            = $tagFilters
    excludeTags     = $excludeFilters
  }
  targets          = $selectedTargets
  resultsDirectory = $resultsFull
}
$summaryPayload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $summaryJsonPath -Encoding utf8

$writeFailures = ($failed -gt 0 -or $EmitFailuresJsonAlways)
if ($writeFailures) {
  $failureEntries = @()
  foreach ($test in $pesterRun.Failed) {
    $message = ''
    $stack = ''
    $file = $null
    $line = $null
    if ($test.ErrorRecord -and $test.ErrorRecord.Exception) {
      $message = [string]$test.ErrorRecord.Exception.Message
    }
    if ($test.ErrorRecord -and $test.ErrorRecord.ScriptStackTrace) {
      $stack = [string]$test.ErrorRecord.ScriptStackTrace
    }
    if ($test.ScriptBlock -and $test.ScriptBlock.File) {
      $file = $test.ScriptBlock.File
    }
    if ($test.StartLine) {
      $line = [int]$test.StartLine
    }
    $failureEntries += [ordered]@{
      name    = $test.Name
      file    = $file
      line    = $line
      message = $message
      stack   = $stack
    }
  }
  if ($failureEntries -or $EmitFailuresJsonAlways) {
    $failureEntries | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $failuresJsonPath -Encoding utf8
  }
}

if ($failed -gt 0 -or $errors -gt 0) {
  $color = 'Red'
  $exitCode = 1
} else {
  $color = 'Green'
  $exitCode = 0
}
Write-Host ("[dispatcher] Tests Passed: {0} Failed: {1} Skipped: {2} Duration(s): {3}" -f $passed, $failed, $skipped, $durationSeconds) -ForegroundColor $color

exit $exitCode
