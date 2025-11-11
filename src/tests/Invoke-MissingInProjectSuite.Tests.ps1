[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
param(
  [Parameter()][ValidateSet('2021','2023','2025')][string]$LabVIEWVersion = '2023',
  [Parameter()][ValidateSet(32,64)][int]$Bitness = 64,
  [Parameter()][ValidateNotNullOrEmpty()][string]$Workspace = (Get-Location).Path,
  [Parameter()][int]$TimeoutSec = 600
)

Describe 'Invoke-MissingInProjectSuite.ps1' -Tag 'Unit','IconEditor','MissingInProject' {
  BeforeAll {
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:scriptPath = Join-Path $script:repoRoot 'tools' 'icon-editor' 'Invoke-MissingInProjectSuite.ps1'
    $script:invokePesterPath = Join-Path $script:repoRoot 'Invoke-PesterTests.ps1'
    $script:analyzerDefaultPath = Join-Path $script:repoRoot 'tools' 'report' 'Analyze-CompareReportImages.ps1'
    $script:viAnalyzerScriptPath = Join-Path $script:repoRoot 'tools' 'icon-editor' 'Invoke-VIAnalyzer.ps1'
    $script:reportsDir = Join-Path $script:repoRoot 'tests' 'results' '_agent' 'reports' 'missing-in-project'

    Test-Path -LiteralPath $script:scriptPath | Should -BeTrue
    Test-Path -LiteralPath $script:invokePesterPath | Should -BeTrue

    $script:newStubCommand = {
      param([string]$Content)
      $backupPath = Join-Path $TestDrive ("Invoke-PesterTests-{0}.ps1" -f ([guid]::NewGuid().ToString('n')))
      Copy-Item -LiteralPath $script:invokePesterPath -Destination $backupPath
      Set-Content -LiteralPath $script:invokePesterPath -Value $Content -Encoding utf8
      return $backupPath
    }

    $script:restoreStubCommand = {
      param([string]$BackupPath)
      if ($BackupPath -and (Test-Path -LiteralPath $BackupPath)) {
        Move-Item -LiteralPath $BackupPath -Destination $script:invokePesterPath -Force
      }
    }

    $script:getReportCommand = {
      param([string]$Label)
      if (-not (Test-Path -LiteralPath $script:reportsDir -PathType Container)) {
        return $null
      }
      return Get-ChildItem -LiteralPath $script:reportsDir -Filter ("{0}-*.json" -f $Label) -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTimeUtc |
        Select-Object -Last 1
    }

    $script:newViAnalyzerStubCommand = {
      param([string]$Content)
      $backupPath = Join-Path $TestDrive ("Invoke-VIAnalyzer-{0}.ps1" -f ([guid]::NewGuid().ToString('n')))
      Copy-Item -LiteralPath $script:viAnalyzerScriptPath -Destination $backupPath
      Set-Content -LiteralPath $script:viAnalyzerScriptPath -Value $Content -Encoding utf8
      return $backupPath
    }

    $script:restoreViAnalyzerStubCommand = {
      param([string]$BackupPath)
      if ($BackupPath -and (Test-Path -LiteralPath $BackupPath)) {
        Move-Item -LiteralPath $BackupPath -Destination $script:viAnalyzerScriptPath -Force
      }
    }
  }

  AfterEach {
    Remove-Item Env:INVOCATION_LOG_PATH -ErrorAction SilentlyContinue
    Remove-Item Env:MIP_SKIP_NEGATIVE -ErrorAction SilentlyContinue
    Remove-Item Env:COMPAREVI_REPORTS_ROOT -ErrorAction SilentlyContinue
    Remove-Item Env:MIP_TEST_EXIT -ErrorAction SilentlyContinue
    Remove-Item Env:MIP_LABEL_BRANCH -ErrorAction SilentlyContinue
    Remove-Item Env:MIP_LABEL_SHA -ErrorAction SilentlyContinue
    Remove-Item Env:MIP_COMPARE_ANALYZER -ErrorAction SilentlyContinue
    Remove-Item Env:MIP_VIANALYZER_CONFIG -ErrorAction SilentlyContinue
    Remove-Item Env:MIP_DEV_MODE_RETRY_ON_BROKEN_VI -ErrorAction SilentlyContinue
    Remove-Item Env:MIP_DEV_MODE_RECOVERY_HELPER -ErrorAction SilentlyContinue
    Remove-Item Env:MIP_DEV_MODE_VERSIONS -ErrorAction SilentlyContinue
    Remove-Item Env:MIP_DEV_MODE_BITNESS -ErrorAction SilentlyContinue
    Remove-Item Env:MIP_DEV_MODE_RETRY_DELAY_SECONDS -ErrorAction SilentlyContinue
  }

  It 'writes a run report and toggles MIP_SKIP_NEGATIVE by default' {
    $label = "unit-mip-{0}" -f ([guid]::NewGuid().ToString('n').Substring(0, 6))
    $resultsDir = Join-Path $TestDrive 'mip-success-results'
    $reportsRoot = Join-Path $TestDrive 'reports-root'
    Remove-Item -LiteralPath $reportsRoot -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $reportsRoot -Force | Out-Null
    $stub = @'
param(
  [string]$TestsPath,
  [string]$ResultsPath,
  [string]$IntegrationMode
)
if (-not $ResultsPath) { throw 'ResultsPath argument missing.' }
if (-not (Test-Path -LiteralPath $ResultsPath -PathType Container)) {
  $null = New-Item -ItemType Directory -Path $ResultsPath -Force
}
if ($TestsPath) {
  Set-Content -LiteralPath (Join-Path $ResultsPath 'tests-path.txt') -Value $TestsPath
}
Set-Content -LiteralPath (Join-Path $ResultsPath 'pester-summary.txt') -Value 'Stub MissingInProject summary'
Set-Content -LiteralPath (Join-Path $ResultsPath 'skip-state.txt') -Value $env:MIP_SKIP_NEGATIVE
exit 0
'@
    $backup = & $script:newStubCommand $stub
    $configPath = Join-Path $TestDrive 'missing-in-project.viancfg'
    '{}' | Set-Content -LiteralPath $configPath -Encoding utf8
    $analyzerStub = @"
param(
  [string]$ConfigPath,
  [string]$OutputRoot,
  [string]$LabVIEWVersion,
  [int]$Bitness,
  [switch]$PassThru
)
$reportPath = Join-Path $OutputRoot 'vi-analyzer-report.html'
$cliLogPath = Join-Path $OutputRoot 'vi-analyzer-cli.log'
'report' | Set-Content -LiteralPath $reportPath -Encoding utf8
'log' | Set-Content -LiteralPath $cliLogPath -Encoding utf8
$result = [pscustomobject]@{
  reportPath = $reportPath
  cliLogPath = $cliLogPath
  brokenViCount = 0
  configSourcePath = $ConfigPath
}
if ($PassThru) { return $result }
"@
    $analyzerBackup = & $script:newViAnalyzerStubCommand $analyzerStub
    Remove-Item Env:MIP_SKIP_NEGATIVE -ErrorAction SilentlyContinue
    $env:INVOCATION_LOG_PATH = 'C:\logs\mip.log'
    $env:COMPAREVI_REPORTS_ROOT = $reportsRoot
    $reportsDir = Join-Path $reportsRoot 'tests\results\_agent\reports\missing-in-project'
    $reportsBefore = @()
    if (Test-Path -LiteralPath $reportsDir -PathType Container) {
      $reportsBefore = Get-ChildItem -LiteralPath $reportsDir -Filter ("{0}-*.json" -f $label) -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
    }
    try {
      { & $script:scriptPath -Label $label -ResultsPath $resultsDir -ViAnalyzerConfigPath $configPath -ViAnalyzerVersion 2023 -ViAnalyzerBitness 64 } | Should -Not -Throw

      $runDir = Join-Path $resultsDir $label
      Test-Path -LiteralPath $runDir -PathType Container | Should -BeTrue

      $summaryPath = Join-Path $runDir 'pester-summary.txt'
      Test-Path -LiteralPath $summaryPath -PathType Leaf | Should -BeTrue
      $summaryMirror = Join-Path $resultsDir 'pester-summary.txt'
      Test-Path -LiteralPath $summaryMirror -PathType Leaf | Should -BeTrue
      (Get-Content -LiteralPath $summaryMirror -Raw).Trim() | Should -Be 'Stub MissingInProject summary'

      $testsPathFile = Join-Path $runDir 'tests-path.txt'
      Test-Path -LiteralPath $testsPathFile -PathType Leaf | Should -BeTrue
      (Get-Content -LiteralPath $testsPathFile -Raw).Trim() | Should -Be (Join-Path $script:repoRoot 'tests\IconEditorMissingInProject.CompareOnly.Tests.ps1')

      $skipStatePath = Join-Path $runDir 'skip-state.txt'
      (Get-Content -LiteralPath $skipStatePath -Raw).Trim() | Should -Be '1'
      [Environment]::GetEnvironmentVariable('MIP_SKIP_NEGATIVE') | Should -BeNullOrEmpty

      Test-Path -LiteralPath $reportsDir -PathType Container | Should -BeTrue
      $reportFile = Get-ChildItem -LiteralPath $reportsDir -Filter ("{0}-*.json" -f $label) -ErrorAction SilentlyContinue |
        Where-Object { $reportsBefore -notcontains $_.FullName } |
        Sort-Object LastWriteTimeUtc |
        Select-Object -Last 1
      $reportFile | Should -Not -BeNullOrEmpty
      $reportJson = Get-Content -LiteralPath $reportFile.FullName -Raw | ConvertFrom-Json -Depth 6
      $reportJson.kind | Should -Be 'missing-in-project'
      $reportJson.summary | Should -Match 'Stub MissingInProject summary'
      $reportJson.telemetryPath | Should -Be $summaryPath
      $reportJson.extra.resultsPath | Should -Be $runDir
      $reportJson.extra.includeNegative | Should -BeFalse

      $pointerPath = Join-Path $resultsDir 'latest-run.json'
      Test-Path -LiteralPath $pointerPath -PathType Leaf | Should -BeTrue
      $pointer = Get-Content -LiteralPath $pointerPath -Raw | ConvertFrom-Json
      $pointer.label | Should -Be $label
      $pointer.runPath | Should -Be $runDir

      $indexPath = Join-Path $resultsDir 'run-index.json'
      Test-Path -LiteralPath $indexPath -PathType Leaf | Should -BeTrue
      $index = Get-Content -LiteralPath $indexPath -Raw | ConvertFrom-Json
      $index[0].label | Should -Be $label
      $index[0].runPath | Should -Be $runDir

      $sessionPath = Join-Path $runDir 'missing-in-project-session.json'
      Test-Path -LiteralPath $sessionPath -PathType Leaf | Should -BeTrue
      $session = Get-Content -LiteralPath $sessionPath -Raw | ConvertFrom-Json -Depth 6
      $session.schema | Should -Be 'missing-in-project/run@v1'
      $session.label | Should -Be $label
      $session.suite.testsPath | Should -Be (Join-Path $script:repoRoot 'tests\IconEditorMissingInProject.CompareOnly.Tests.ps1')
      $session.suite.includeNegative | Should -BeFalse
      $session.viAnalyzer.invoked | Should -BeTrue
      $session.viAnalyzer.configPath | Should -Be (Resolve-Path -LiteralPath $configPath).Path
      $session.viAnalyzer.reportPath | Should -Be (Join-Path $runDir 'vi-analyzer-report.html')
      $session.reports.missingInProject | Should -Be $reportFile.FullName
      ($session.compare.reportPath) | Should -BeNullOrEmpty

      Remove-Item -LiteralPath $reportFile.FullName -ErrorAction SilentlyContinue
    }
    finally {
      & $script:restoreStubCommand $backup
      & $script:restoreViAnalyzerStubCommand $analyzerBackup
      Remove-Item Env:INVOCATION_LOG_PATH -ErrorAction SilentlyContinue
      Remove-Item Env:MIP_SKIP_NEGATIVE -ErrorAction SilentlyContinue
      Remove-Item Env:COMPAREVI_REPORTS_ROOT -ErrorAction SilentlyContinue
    }
  }

  It 'auto-generates a label when omitted using branch + sha metadata' {
    $resultsDir = Join-Path $TestDrive 'mip-auto-label'
    $reportsRoot = Join-Path $TestDrive 'reports-auto-label'
    Remove-Item -LiteralPath $reportsRoot -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $reportsRoot -Force | Out-Null

    $stub = @'
param(
  [string]$ResultsPath,
  [string]$TestsPath,
  [string]$IntegrationMode
)
if (-not $ResultsPath) { throw 'ResultsPath argument missing.' }
if (-not (Test-Path -LiteralPath $ResultsPath -PathType Container)) {
  $null = New-Item -ItemType Directory -Path $ResultsPath -Force
}
Set-Content -LiteralPath (Join-Path $ResultsPath 'pester-summary.txt') -Value 'Auto summary'
exit 0
'@
    $backup = & $script:newStubCommand $stub
    $env:MIP_LABEL_BRANCH = 'feature/Auto_Label'
    $env:MIP_LABEL_SHA = 'ABC1234'
    $env:COMPAREVI_REPORTS_ROOT = $reportsRoot
    try {
      { & $script:scriptPath -ResultsPath $resultsDir } | Should -Not -Throw

      $pointerPath = Join-Path $resultsDir 'latest-run.json'
      Test-Path -LiteralPath $pointerPath -PathType Leaf | Should -BeTrue
      $pointer = Get-Content -LiteralPath $pointerPath -Raw | ConvertFrom-Json
      $pointer.label | Should -Match '^mip-feature-auto-label-abc1234-\d{8}T\d{6}$'
      Test-Path -LiteralPath $pointer.runPath -PathType Container | Should -BeTrue
    }
    finally {
      & $script:restoreStubCommand $backup
      Remove-Item Env:MIP_LABEL_BRANCH -ErrorAction SilentlyContinue
      Remove-Item Env:MIP_LABEL_SHA -ErrorAction SilentlyContinue
      Remove-Item Env:COMPAREVI_REPORTS_ROOT -ErrorAction SilentlyContinue
    }
  }

  It 'allows selecting the full suite explicitly' {
    $label = "unit-mip-full-{0}" -f ([guid]::NewGuid().ToString('n').Substring(0, 6))
    $resultsDir = Join-Path $TestDrive 'mip-full-results'
    $reportsRoot = Join-Path $TestDrive 'reports-full'
    New-Item -ItemType Directory -Path $reportsRoot -Force | Out-Null
    $stub = @'
param(
  [string]$TestsPath,
  [string]$ResultsPath,
  [string]$IntegrationMode
)
if (-not $ResultsPath) { throw 'ResultsPath argument missing.' }
if (-not (Test-Path -LiteralPath $ResultsPath -PathType Container)) {
  $null = New-Item -ItemType Directory -Path $ResultsPath -Force
}
if ($TestsPath) {
  Set-Content -LiteralPath (Join-Path $ResultsPath 'tests-path.txt') -Value $TestsPath
}
Set-Content -LiteralPath (Join-Path $ResultsPath 'pester-summary.txt') -Value 'Stub MissingInProject summary'
exit 0
'@
    $backup = & $script:newStubCommand $stub
    $env:COMPAREVI_REPORTS_ROOT = $reportsRoot
    try {
      { & $script:scriptPath -Label $label -ResultsPath $resultsDir -TestSuite full } | Should -Not -Throw
      $runDir = Join-Path $resultsDir $label
      $testsPathFile = Join-Path $runDir 'tests-path.txt'
      (Get-Content -LiteralPath $testsPathFile -Raw).Trim() | Should -Be (Join-Path $script:repoRoot 'tests\IconEditorMissingInProject.DevMode.Tests.ps1')
    }
    finally {
      & $script:restoreStubCommand $backup
      Remove-Item Env:COMPAREVI_REPORTS_ROOT -ErrorAction SilentlyContinue
    }
  }

  It 'restores MIP_SKIP_NEGATIVE when IncludeNegative is used and failures bubble up' {
    $label = "unit-mip-fail-{0}" -f ([guid]::NewGuid().ToString('n').Substring(0, 6))
    $resultsDir = Join-Path $TestDrive 'mip-fail-results'
    $reportsRoot = Join-Path $TestDrive 'reports-root-fail'
    Remove-Item -LiteralPath $reportsRoot -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $reportsRoot -Force | Out-Null
    $stub = @'
param(
  [string]$TestsPath,
  [string]$ResultsPath,
  [string]$IntegrationMode
)
if (-not $ResultsPath) { throw 'ResultsPath argument missing.' }
if (-not (Test-Path -LiteralPath $ResultsPath -PathType Container)) {
  $null = New-Item -ItemType Directory -Path $ResultsPath -Force
}
if ($TestsPath) {
  Set-Content -LiteralPath (Join-Path $ResultsPath 'tests-path.txt') -Value $TestsPath
}
Set-Content -LiteralPath (Join-Path $ResultsPath 'skip-state.txt') -Value $env:MIP_SKIP_NEGATIVE
$exitRaw = [Environment]::GetEnvironmentVariable('MIP_TEST_EXIT')
if ([string]::IsNullOrWhiteSpace($exitRaw)) {
  exit 0
}
exit ([int]$exitRaw)
'@
    $backup = & $script:newStubCommand $stub
    $env:MIP_SKIP_NEGATIVE = 'original'
    $env:MIP_TEST_EXIT = '9'
    $env:COMPAREVI_REPORTS_ROOT = $reportsRoot
    $reportsDir = Join-Path $reportsRoot 'tests\results\_agent\reports\missing-in-project'
    $reportsBefore = if (Test-Path -LiteralPath $reportsDir -PathType Container) {
      Get-ChildItem -LiteralPath $reportsDir -Filter ("{0}-*.json" -f $label) -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
    } else { @() }
    try {
      Should -ActualValue { & $script:scriptPath -Label $label -IncludeNegative -ResultsPath $resultsDir } -Throw

      [Environment]::GetEnvironmentVariable('MIP_SKIP_NEGATIVE') | Should -Be 'original'
      if (Test-Path -LiteralPath $reportsDir -PathType Container) {
        $reportFile = Get-ChildItem -LiteralPath $reportsDir -Filter ("{0}-*.json" -f $label) -ErrorAction SilentlyContinue |
          Where-Object { $reportsBefore -notcontains $_.FullName } |
          Select-Object -Last 1
        $reportFile | Should -BeNullOrEmpty
      }
    }
    finally {
      & $script:restoreStubCommand $backup
    }
  }

  It 'cleans existing artifacts and mirrors latest outputs to the root when requested' {
    $label = "unit-mip-clean-{0}" -f ([guid]::NewGuid().ToString('n').Substring(0, 6))
    $resultsDir = Join-Path $TestDrive 'mip-clean-results'
    New-Item -ItemType Directory -Path $resultsDir -Force | Out-Null
    $sentinelPath = Join-Path $resultsDir 'compare-report.html'
    Set-Content -LiteralPath $sentinelPath -Value 'stale-report'

    $stub = @'
param(
  [string]$TestsPath,
  [string]$ResultsPath,
  [string]$IntegrationMode
)
if (-not $ResultsPath) { throw 'ResultsPath argument missing.' }
if (-not (Test-Path -LiteralPath $ResultsPath -PathType Container)) {
  $null = New-Item -ItemType Directory -Path $ResultsPath -Force
}
if ($TestsPath) {
  Set-Content -LiteralPath (Join-Path $ResultsPath 'tests-path.txt') -Value $TestsPath
}
Set-Content -LiteralPath (Join-Path $ResultsPath 'pester-summary.txt') -Value 'Fresh summary'
Set-Content -LiteralPath (Join-Path $ResultsPath 'compare-report.html') -Value 'fresh-report'
exit 0
'@
    $backup = & $script:newStubCommand $stub
    try {
      { & $script:scriptPath -Label $label -ResultsPath $resultsDir -CleanResults } | Should -Not -Throw

      $runDir = Join-Path $resultsDir $label
      (Get-Content -LiteralPath (Join-Path $runDir 'compare-report.html') -Raw).Trim() | Should -Be 'fresh-report'
      (Get-Content -LiteralPath (Join-Path $resultsDir 'compare-report.html') -Raw).Trim() | Should -Be 'fresh-report'

      $pointerPath = Join-Path $resultsDir 'latest-run.json'
      (Get-Content -LiteralPath $pointerPath -Raw | ConvertFrom-Json).label | Should -Be $label
    }
    finally {
      & $script:restoreStubCommand $backup
    }
  }

  It 'fails when RequireCompareReport is set but compare report is missing' {
    $label = "unit-mip-requirefail"
    $resultsDir = Join-Path $TestDrive 'mip-require-fail'
    $stub = @'
param(
  [string]$TestsPath,
  [string]$ResultsPath,
  [string]$IntegrationMode
)
New-Item -ItemType Directory -Path $ResultsPath -Force | Out-Null
if ($TestsPath) {
  Set-Content -LiteralPath (Join-Path $ResultsPath 'tests-path.txt') -Value $TestsPath
}
Set-Content -LiteralPath (Join-Path $ResultsPath 'pester-summary.txt') -Value 'summary'
exit 0
'@
    $backup = & $script:newStubCommand $stub
    try {
      { & $script:scriptPath -Label $label -ResultsPath $resultsDir -RequireCompareReport } | Should -Throw '*compare-report.html not found*'
    }
    finally {
      & $script:restoreStubCommand $backup
    }
  }

  It 'runs analyzer and enforces heuristics when RequireCompareReport is set' {
    $label = "unit-mip-analyzer-pass"
    $resultsDir = Join-Path $TestDrive 'mip-analyzer-pass'
    $stubPester = @'
param(
  [string]$TestsPath,
  [string]$ResultsPath,
  [string]$IntegrationMode
)
New-Item -ItemType Directory -Path $ResultsPath -Force | Out-Null
Set-Content -LiteralPath (Join-Path $ResultsPath 'pester-summary.txt') -Value 'summary'
Set-Content -LiteralPath (Join-Path $ResultsPath 'compare-report.html') -Value '<img src="bd.png" />'
exit 0
'@
    $stubAnalyzer = @'
param(
  [string]$ReportHtmlPath,
  [string]$RunDir,
  [string]$RootDir,
  [string]$OutManifestPath
)
if (-not $OutManifestPath) { $OutManifestPath = Join-Path $RunDir 'compare-image-manifest.json' }
$manifest = @{
  totals = @{
    references = 2
    existing   = 2
    missing    = 0
    zeroSize   = 0
    largeSize  = 0
    stale      = 0
    dupGroups  = 0
  }
  duplicates = @()
}
$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $OutManifestPath
Set-Content -LiteralPath (Join-Path $RootDir 'compare-image-summary.json') -Value '{"ok":true}'
Write-Output $OutManifestPath
'@
    $backup = & $script:newStubCommand $stubPester
    $analyzerStubPath = Join-Path $TestDrive 'analyzer-pass.ps1'
    Set-Content -LiteralPath $analyzerStubPath -Value $stubAnalyzer -Encoding utf8
    $env:MIP_COMPARE_ANALYZER = $analyzerStubPath
    try {
      { & $script:scriptPath -Label $label -ResultsPath $resultsDir -RequireCompareReport } | Should -Not -Throw
      $pointerPath = Join-Path $resultsDir 'latest-run.json'
      $pointer = Get-Content -LiteralPath $pointerPath -Raw | ConvertFrom-Json
      $pointer.label | Should -Be $label
      Test-Path -LiteralPath (Join-Path $resultsDir 'compare-image-manifest.json') -PathType Leaf | Should -BeTrue
      $runDir = Join-Path $resultsDir $label
      $sessionPath = Join-Path $runDir 'missing-in-project-session.json'
      Test-Path -LiteralPath $sessionPath -PathType Leaf | Should -BeTrue
      $session = Get-Content -LiteralPath $sessionPath -Raw | ConvertFrom-Json -Depth 6
      $session.compare.reportPath | Should -Be (Join-Path $runDir 'compare-report.html')
      $session.compare.manifestPath | Should -Be (Join-Path $runDir 'compare-image-manifest.json')
    }
    finally {
      & $script:restoreStubCommand $backup
    }
  }

  It 'fails when analyzer detects missing images under RequireCompareReport' {
    $label = "unit-mip-analyzer-fail"
    $resultsDir = Join-Path $TestDrive 'mip-analyzer-fail'
    $stubPester = @'
param(
  [string]$TestsPath,
  [string]$ResultsPath,
  [string]$IntegrationMode
)
New-Item -ItemType Directory -Path $ResultsPath -Force | Out-Null
Set-Content -LiteralPath (Join-Path $ResultsPath 'pester-summary.txt') -Value 'summary'
Set-Content -LiteralPath (Join-Path $ResultsPath 'compare-report.html') -Value '<img src="missing.png" />'
exit 0
'@
    $stubAnalyzer = @'
param(
  [string]$ReportHtmlPath,
  [string]$RunDir,
  [string]$RootDir,
  [string]$OutManifestPath
)
if (-not $OutManifestPath) { $OutManifestPath = Join-Path $RunDir 'compare-image-manifest.json' }
$manifest = @{
  totals = @{
    references = 1
    existing   = 0
    missing    = 1
    zeroSize   = 0
    largeSize  = 0
    stale      = 0
    dupGroups  = 0
  }
  duplicates = @()
}
$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $OutManifestPath
Set-Content -LiteralPath (Join-Path $RootDir 'compare-image-summary.json') -Value '{"ok":false}'
Write-Output $OutManifestPath
'@
    $backup = & $script:newStubCommand $stubPester
    $analyzerStubPath = Join-Path $TestDrive 'analyzer-fail.ps1'
    Set-Content -LiteralPath $analyzerStubPath -Value $stubAnalyzer -Encoding utf8
    $env:MIP_COMPARE_ANALYZER = $analyzerStubPath
    try {
      { & $script:scriptPath -Label $label -ResultsPath $resultsDir -RequireCompareReport } | Should -Throw '*Compare report gate failed*'
    }
    finally {
      & $script:restoreStubCommand $backup
    }
  }

  It 'fails when VI Analyzer detects broken VIs before running the suite' {
    $label = "unit-mip-vianalyzer-fail"
    $resultsDir = Join-Path $TestDrive 'mip-vianalyzer-fail'
    $configPath = Join-Path $TestDrive 'vi-analyzer.viancfg'
    Set-Content -LiteralPath $configPath -Value '<VIAnalyzer></VIAnalyzer>' -Encoding utf8
    $env:MIP_DEV_MODE_RETRY_ON_BROKEN_VI = '0'
    $pesterStub = @'
param(
  [string]$TestsPath,
  [string]$ResultsPath,
  [string]$IntegrationMode
)
exit 0
'@
    $pesterBackup = & $script:newStubCommand $pesterStub

    $analyzerStub = @'
param(
  [string]$ConfigPath,
  [string]$OutputRoot,
  [int]$LabVIEWVersion,
  [int]$Bitness,
  [switch]$PassThru
)
if (-not (Test-Path -LiteralPath $OutputRoot -PathType Container)) {
  New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
}
$runDir = Join-Path $OutputRoot 'stub-run'
New-Item -ItemType Directory -Path $runDir -Force | Out-Null
$report = Join-Path $runDir 'report.txt'
Set-Content -LiteralPath $report -Value 'stub report'
$result = [pscustomobject]@{
  reportPath    = $report
  runDir        = $runDir
  brokenViCount = 1
  brokenVis     = ,([pscustomobject]@{ vi = 'C:\Broken.vi'; category = 'VI Properties'; test = 'Broken VI'; details = 'broken' })
  configSourcePath = $ConfigPath
}
if ($PassThru) { return $result }
'@
    $analyzerBackup = & $script:newViAnalyzerStubCommand $analyzerStub

    try {
      { & $script:scriptPath -Label $label -ResultsPath $resultsDir -ViAnalyzerConfigPath $configPath } | Should -Throw '*VI Analyzer detected broken VIs*'
    }
    finally {
      & $script:restoreStubCommand $pesterBackup
      & $script:restoreViAnalyzerStubCommand $analyzerBackup
    }
  }

  It 'retries VI Analyzer once after dev-mode recovery succeeds' {
    $label = "unit-mip-vianalyzer-retry"
    $resultsDir = Join-Path $TestDrive 'mip-vianalyzer-retry'
    $configPath = Join-Path $TestDrive 'vi-analyzer-retry.viancfg'
    Set-Content -LiteralPath $configPath -Value '<VIAnalyzer></VIAnalyzer>' -Encoding utf8

    $pesterStub = @'
param(
  [string]$TestsPath,
  [string]$ResultsPath,
  [string]$IntegrationMode
)
if (-not (Test-Path -LiteralPath $ResultsPath -PathType Container)) {
  $null = New-Item -ItemType Directory -Path $ResultsPath -Force
}
Set-Content -LiteralPath (Join-Path $ResultsPath 'pester-summary.txt') -Value 'retry summary'
exit 0
'@
    $pesterBackup = & $script:newStubCommand $pesterStub

    $callCountPath = Join-Path $TestDrive 'vi-analyzer-calls.txt'
    $analyzerStub = @"
param(
  [string]`$ConfigPath,
  [string]`$OutputRoot,
  [int]`$LabVIEWVersion,
  [int]`$Bitness,
  [switch]`$PassThru
)
if (-not (Test-Path -LiteralPath `$OutputRoot -PathType Container)) {
  New-Item -ItemType Directory -Path `$OutputRoot -Force | Out-Null
}
`$attempt = 0
if (Test-Path -LiteralPath '$callCountPath' -PathType Leaf) {
  `$attempt = [int](Get-Content -LiteralPath '$callCountPath' -Raw)
}
`$attempt++
Set-Content -LiteralPath '$callCountPath' -Value `$attempt
`$runDir = Join-Path `$OutputRoot ("run-{0}" -f `$attempt)
New-Item -ItemType Directory -Path `$runDir -Force | Out-Null
`$report = Join-Path `$runDir 'report.txt'
Set-Content -LiteralPath `$report -Value ("attempt {0}" -f `$attempt)
`$brokenCount = if (`$attempt -eq 1) { 1 } else { 0 }
`$brokenList = if (`$brokenCount -gt 0) {
  ,([pscustomobject]@{ vi = 'C:\Broken.vi'; category = 'VI Properties'; test = 'Broken VI'; details = 'broken' })
} else {
  @()
}
$configSource = `$ConfigPath
try {
  `$resolvedSource = Resolve-Path -LiteralPath `$ConfigPath -ErrorAction Stop
  if (`$resolvedSource) { $configSource = `$resolvedSource.Path }
} catch {}
`$result = [pscustomobject]@{
  reportPath    = `$report
  runDir        = `$runDir
  brokenViCount = `$brokenCount
  brokenVis     = `$brokenList
  configSourcePath = `$configSource
}
if (`$PassThru) { return `$result }
"@
    $analyzerBackup = & $script:newViAnalyzerStubCommand $analyzerStub

    $recoveryLog = Join-Path $TestDrive 'devmode-recovery.json'
    $recoveryHelper = Join-Path $TestDrive 'devmode-recovery-helper.ps1'
    $recoveryContent = @"
param(
  [string]`$RepoRoot,
  [int[]]`$Versions,
  [int[]]`$Bitness,
  [string]`$Operation
)
`$payload = [ordered]@{
  repoRoot  = `$RepoRoot
  versions  = `$Versions
  bitness   = `$Bitness
  operation = `$Operation
  timestamp = (Get-Date).ToString('o')
}
`$payload | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath '$recoveryLog' -Encoding utf8
"@
    Set-Content -LiteralPath $recoveryHelper -Value $recoveryContent -Encoding utf8

    $env:MIP_DEV_MODE_RETRY_ON_BROKEN_VI = '1'
    $env:MIP_DEV_MODE_RECOVERY_HELPER = $recoveryHelper
    $env:MIP_DEV_MODE_RETRY_DELAY_SECONDS = '0'

    try {
      { & $script:scriptPath -Label $label -ResultsPath $resultsDir -ViAnalyzerConfigPath $configPath } | Should -Not -Throw

      Test-Path -LiteralPath $callCountPath -PathType Leaf | Should -BeTrue
      [int](Get-Content -LiteralPath $callCountPath -Raw) | Should -Be 2
      Test-Path -LiteralPath $recoveryLog -PathType Leaf | Should -BeTrue

      $reportEntry = & $script:getReportCommand $label
      $reportEntry | Should -Not -BeNullOrEmpty
      Test-Path -LiteralPath $reportEntry.FullName -PathType Leaf | Should -BeTrue
      $reportJson = Get-Content -LiteralPath $reportEntry.FullName -Raw | ConvertFrom-Json
      $reportJson.extra.viAnalyzer.retry.attempted | Should -BeTrue
      $reportJson.extra.viAnalyzer.retry.succeeded | Should -BeTrue
      $reportJson.extra.viAnalyzer.retry.targets.versions | Should -Not -BeNullOrEmpty
    }
    finally {
      & $script:restoreStubCommand $pesterBackup
      & $script:restoreViAnalyzerStubCommand $analyzerBackup
    }
  }

  It 'fails with a clear message when VI Analyzer reports a newer saved version' {
    $label = "unit-mip-vianalyzer-version"
    $resultsDir = Join-Path $TestDrive 'mip-vianalyzer-version'
    $configPath = Join-Path $TestDrive 'vi-analyzer-version.viancfg'
    Set-Content -LiteralPath $configPath -Value '<VIAnalyzer></VIAnalyzer>' -Encoding utf8
    $env:MIP_DEV_MODE_RETRY_ON_BROKEN_VI = '0'

    $pesterStub = @'
param(
  [string]$TestsPath,
  [string]$ResultsPath,
  [string]$IntegrationMode
)
exit 0
'@
    $pesterBackup = & $script:newStubCommand $pesterStub

    $analyzerStub = @"
param(
  [string]$ConfigPath,
  [string]$OutputRoot,
  [int]$LabVIEWVersion,
  [int]$Bitness,
  [switch]$PassThru
)
$result = [pscustomobject]@{
  reportPath = 'C:\logs\analyzer.html'
  runDir = 'C:\logs'
  brokenViCount = 0
  brokenVis = @()
  versionMismatchCount = 1
  versionMismatches = @([pscustomobject]@{
      vi = 'Base.vi'
      path = 'C:\repo\Base.vi'
      analyzerVersion = $LabVIEWVersion
      analyzerBitness = $Bitness
      details = 'Base.vi	C:\repo\Base.vi	Error 1125.  This VI is saved in a LabVIEW version newer than the one you are using.'
    })
}
if ($PassThru) { return $result }
'@
    $analyzerBackup = & $script:newViAnalyzerStubCommand $analyzerStub

    try {
      { & $script:scriptPath -Label $label -ResultsPath $resultsDir -ViAnalyzerConfigPath $configPath -ViAnalyzerVersion 2023 -ViAnalyzerBitness 64 } |
        Should -Throw '*saved in a newer LabVIEW version*LabVIEW 2023 (64-bit)*'
    }
    finally {
      & $script:restoreStubCommand $pesterBackup
      & $script:restoreViAnalyzerStubCommand $analyzerBackup
    }
  }

  It 'records analyzer metadata when the gate passes' {
    $label = "unit-mip-vianalyzer-pass"
    $resultsDir = Join-Path $TestDrive 'mip-vianalyzer-pass'
    $reportsRoot = Join-Path $TestDrive 'reports-vianalyzer-pass'
    New-Item -ItemType Directory -Path $reportsRoot -Force | Out-Null
    $configPath = Join-Path $TestDrive 'vi-analyzer-pass.viancfg'
    Set-Content -LiteralPath $configPath -Value '<VIAnalyzer></VIAnalyzer>' -Encoding utf8
    $env:COMPAREVI_REPORTS_ROOT = $reportsRoot

    $pesterStub = @'
param(
  [string]$TestsPath,
  [string]$ResultsPath,
  [string]$IntegrationMode
)
if (-not (Test-Path -LiteralPath $ResultsPath -PathType Container)) {
  $null = New-Item -ItemType Directory -Path $ResultsPath -Force
}
Set-Content -LiteralPath (Join-Path $ResultsPath 'pester-summary.txt') -Value 'Analyzer pass summary'
exit 0
'@
    $pesterBackup = & $script:newStubCommand $pesterStub

    $analyzerStub = @'
param(
  [string]$ConfigPath,
  [string]$OutputRoot,
  [int]$LabVIEWVersion,
  [int]$Bitness,
  [switch]$PassThru
)
if (-not (Test-Path -LiteralPath $OutputRoot -PathType Container)) {
  New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
}
$runDir = Join-Path $OutputRoot 'stub-run'
New-Item -ItemType Directory -Path $runDir -Force | Out-Null
$report = Join-Path $runDir 'report.txt'
Set-Content -LiteralPath $report -Value 'stub report'
$configSource = $ConfigPath
try {
  $resolvedSource = Resolve-Path -LiteralPath $ConfigPath -ErrorAction Stop
  if ($resolvedSource) { $configSource = $resolvedSource.Path }
} catch {}
$result = [pscustomobject]@{
  reportPath    = $report
  runDir        = $runDir
  brokenViCount = 0
  brokenVis     = @()
  configSourcePath = $configSource
}
if ($PassThru) { return $result }
"@
    $analyzerBackup = & $script:newViAnalyzerStubCommand $analyzerStub

    try {
      { & $script:scriptPath -Label $label -ResultsPath $resultsDir -ViAnalyzerConfigPath $configPath } | Should -Not -Throw

      $reportsDir = Join-Path $reportsRoot 'tests\results\_agent\reports\missing-in-project'
      Test-Path -LiteralPath $reportsDir -PathType Container | Should -BeTrue
      $reportFile = Get-ChildItem -LiteralPath $reportsDir -Filter ("{0}-*.json" -f $label) -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTimeUtc |
        Select-Object -Last 1
      $reportFile | Should -Not -BeNullOrEmpty
      $reportJson = Get-Content -LiteralPath $reportFile.FullName -Raw | ConvertFrom-Json -Depth 6
      $reportJson.extra.viAnalyzer.reportPath | Should -Match 'stub-run'
      $reportJson.extra.viAnalyzer.brokenViCount | Should -Be 0
      $reportJson.extra.viAnalyzer.configPath | Should -Be ((Resolve-Path -LiteralPath $configPath).Path)
      if ($reportJson.extra.viAnalyzer.PSObject.Properties['configSourcePath']) {
        $reportJson.extra.viAnalyzer.configSourcePath | Should -Be ((Resolve-Path -LiteralPath $configPath).Path)
      }
      $reportJson.extra.viAnalyzer.labviewVersion | Should -Be 2023
      $reportJson.extra.viAnalyzer.bitness | Should -Be 64
      $viAnalyzerDir = Join-Path $resultsDir 'vi-analyzer'
      Test-Path -LiteralPath $viAnalyzerDir -PathType Container | Should -BeTrue
    }
    finally {
      & $script:restoreStubCommand $pesterBackup
      & $script:restoreViAnalyzerStubCommand $analyzerBackup
      Remove-Item Env:COMPAREVI_REPORTS_ROOT -ErrorAction SilentlyContinue
    }
  }

  It 'generates a compare report via fallback runner when required and no report exists' {
    $label = "unit-mip-fallback-compare"
    $resultsDir = Join-Path $TestDrive 'mip-fallback-compare'
    $reportsRoot = Join-Path $TestDrive 'reports-fallback-compare'
    New-Item -ItemType Directory -Path $reportsRoot -Force | Out-Null
    $env:COMPAREVI_REPORTS_ROOT = $reportsRoot

    $pesterStub = @'
param(
  [string]$TestsPath,
  [string]$ResultsPath,
  [string]$IntegrationMode
)
if (-not (Test-Path -LiteralPath $ResultsPath -PathType Container)) {
  $null = New-Item -ItemType Directory -Path $ResultsPath -Force
}
Set-Content -LiteralPath (Join-Path $ResultsPath 'pester-summary.txt') -Value 'Stub summary for fallback compare'
exit 0
'@
    $pesterBackup = & $script:newStubCommand $pesterStub

    # Stub runner that writes a simple compare-report.html into the provided OutputRoot
    $runnerStubPath = Join-Path $TestDrive 'runner-stub.ps1'
    Set-Content -LiteralPath $runnerStubPath -Encoding utf8 -Value @'
param(
  [Parameter(Mandatory)][string]$BaseVi,
  [Parameter(Mandatory)][string]$HeadVi,
  [Parameter(Mandatory)][string]$OutputRoot,
  [switch]$RenderReport
)
if (-not (Test-Path -LiteralPath $OutputRoot -PathType Container)) {
  New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
}
$html = "<html><body><h1>Stub Compare</h1><p>$BaseVi vs $HeadVi</p></body></html>"
Set-Content -LiteralPath (Join-Path $OutputRoot 'compare-report.html') -Value $html -Encoding utf8
'@

    # Stub analyzer that writes a minimal manifest and returns its path
    $analyzerStubPath = Join-Path $TestDrive 'analyzer-stub.ps1'
    Set-Content -LiteralPath $analyzerStubPath -Encoding utf8 -Value @'
param(
  [string]$ReportHtmlPath,
  [string]$RunDir,
  [string]$RootDir
)
if (-not (Test-Path -LiteralPath $RootDir -PathType Container)) {
  New-Item -ItemType Directory -Path $RootDir -Force | Out-Null
}
$manifestPath = Join-Path $RootDir 'compare-image-manifest.json'
@{ totals = @{ references = 1; existing = 1; missing = 0; zeroSize = 0; stale = 0; largeSize = 0 }; duplicates = @() } |
  ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $manifestPath -Encoding utf8
Write-Output $manifestPath
'@

    try {
      # Wire env for fallback compare generation
      $env:MIP_COMPARE_RUNNER = $runnerStubPath
      $env:MIP_COMPARE_ANALYZER = $analyzerStubPath
      $env:MIP_COMPARE_BASE = 'C:\\repo\\SampleBase.vi'
      $env:MIP_COMPARE_HEAD = 'C:\\repo\\SampleHead.vi'

      { & $script:scriptPath -Label $label -ResultsPath $resultsDir -RequireCompareReport } | Should -Not -Throw

      $runPath = Join-Path $resultsDir $label
      Test-Path -LiteralPath (Join-Path $runPath 'compare-report.html') -PathType Leaf | Should -BeTrue
      Test-Path -LiteralPath (Join-Path $resultsDir 'compare-image-manifest.json') -PathType Leaf | Should -BeTrue
    }
    finally {
      & $script:restoreStubCommand $pesterBackup
      Remove-Item Env:MIP_COMPARE_RUNNER, Env:MIP_COMPARE_ANALYZER, Env:MIP_COMPARE_BASE, Env:MIP_COMPARE_HEAD -ErrorAction SilentlyContinue
      Remove-Item Env:COMPAREVI_REPORTS_ROOT -ErrorAction SilentlyContinue
    }
  }
}

