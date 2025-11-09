$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Describe 'Invoke-VIAnalyzer.ps1' -Tag 'Unit','IconEditor','VIAnalyzer' {
  BeforeAll {
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:scriptPath = Join-Path $script:repoRoot 'tools' 'icon-editor' 'Invoke-VIAnalyzer.ps1'
    Test-Path -LiteralPath $script:scriptPath | Should -BeTrue
    $script:pwshPath = (Get-Command pwsh).Source
  }

  It 'writes telemetry and captures broken VI entries' {
    $configPath = Join-Path $TestDrive 'task.viancfg'
Set-Content -LiteralPath $configPath -Value '<VIAnalyzer></VIAnalyzer>' -Encoding utf8

    $stubScript = Join-Path $TestDrive 'labviewcli-stub.ps1'
    $stubContent = @'
$reportPath = $null
$resultsPath = $null
for ($i = 0; $i -lt $args.Length; $i++) {
  switch ($args[$i]) {
    '-ReportPath' { $reportPath = $args[++$i]; continue }
    '-ResultsPath' { $resultsPath = $args[++$i]; continue }
    default { continue }
  }
}
if (-not $reportPath) { throw 'ReportPath missing' }
Set-Content -LiteralPath $reportPath -Value @(
  'VI Analyzer Results',
  '',
  'Results',
  "VIs Analyzed`t6",
  "Total Tests Run`t624",
  "Passed Tests`t595",
  "Failed Tests`t29",
  "Skipped Tests`t0",
  '',
  'Errors',
  "VI not loadable`t0",
  "Test not loadable`t0",
  "Test not runnable`t0",
  "Test error out`t0",
  '',
  'Failed Tests (sorted by VI)',
  '',
  'MissingInProject.vi (C:\Examples\MissingInProject.vi)',
  "Wire Crossings`tThis wire has 6 crossings.",
  "Comment Usage`tfewer comments",
  '',
  'MissingInProjectCLI.vi (C:\Examples\MissingInProjectCLI.vi)',
  "Diagram Size`tBlock diagram too wide.",
  "Spell Check`tName misspelled.",
  '',
  'VI: "C:\Examples\Broken.vi"',
  'Category: **VI Properties**',
  '- **Broken VI** - FAILED. This VI is broken and cannot run.',
  'Category: **Style**',
  '- **Icon and Connector** - FAILED. Default icon.',
  '',
  'Testing Errors',
  '(none)'
) -Encoding utf8
if ($resultsPath) {
  Set-Content -LiteralPath $resultsPath -Value 'RSL-STUB' -Encoding utf8
}
exit 0
'@
    Set-Content -LiteralPath $stubScript -Value $stubContent -Encoding utf8
    $stubLauncher = Join-Path $TestDrive 'labviewcli-stub.cmd'
    Set-Content -LiteralPath $stubLauncher -Value "@echo off`npwsh -NoLogo -NoProfile -File ""$stubScript"" %*" -Encoding ascii

    $outputRoot = Join-Path $TestDrive 'results'
    $result = & $script:scriptPath `
      -ConfigPath $configPath `
      -OutputRoot $outputRoot `
      -LabVIEWCLIPath $stubLauncher `
      -CaptureResultsFile `
      -PassThru

    $result | Should -Not -BeNullOrEmpty
    $result.brokenViCount | Should -BeGreaterThan 0
    $result.brokenViNames | Should -Contain 'C:\Examples\Broken.vi'
    $result.failureCount | Should -BeGreaterThan 0
    $result.summary | Should -Not -BeNullOrEmpty
    $result.summary.visAnalyzed | Should -Be 6
    $result.summary.totalTests | Should -Be 624
    $result.summary.testsErrorOut | Should -Be 0
    $result.failedTestsByVi | Should -Not -BeNullOrEmpty
    $projEntry = $result.failedTestsByVi | Where-Object { $_.viName -eq 'MissingInProject.vi' }
    $projEntry | Should -Not -BeNullOrEmpty
    $projEntry.tests.Count | Should -Be 2
    $projEntry.viPath | Should -Be 'C:\Examples\MissingInProject.vi'
    $projEntry.tests[0].test | Should -Be 'Wire Crossings'
    $cliEntry = $result.failedTestsByVi | Where-Object { $_.viName -eq 'MissingInProjectCLI.vi' }
    $cliEntry.tests.Count | Should -Be 2
    ($result.failedTestsByVi | ForEach-Object { $_.tests.Count } | Measure-Object -Sum).Sum | Should -Be 4
    Test-Path -LiteralPath $result.reportPath -PathType Leaf | Should -BeTrue
    Test-Path -LiteralPath $result.runDir -PathType Container | Should -BeTrue
    Test-Path -LiteralPath (Join-Path $result.runDir 'vi-analyzer-cli.log') | Should -BeTrue
    $latestPointer = Join-Path $outputRoot 'latest-run.json'
    Test-Path -LiteralPath $latestPointer -PathType Leaf | Should -BeTrue
    (Get-Content -LiteralPath $result.reportPath | Select-String -Pattern 'Broken VI') | Should -Not -BeNullOrEmpty
  }

  It 'emits RSL files and passes optional CLI flags' {
    $configPath = Join-Path $TestDrive 'task-options.viancfg'
    Set-Content -LiteralPath $configPath -Value '<VIAnalyzer></VIAnalyzer>' -Encoding utf8

    $stubScript = Join-Path $TestDrive 'labviewcli-options.ps1'
    $stubContent = @'
$reportPath = $null
$resultsPath = $null
$state = @{
  ConfigPassword = $null
  ReportSort = $null
  ReportInclude = @()
}
for ($i = 0; $i -lt $args.Length; $i++) {
  switch ($args[$i]) {
    '-ReportPath' { $reportPath = $args[++$i]; continue }
    '-ResultsPath' { $resultsPath = $args[++$i]; continue }
    '-ConfigPassword' { $state.ConfigPassword = $args[++$i]; continue }
    '-ReportSort' { $state.ReportSort = $args[++$i]; continue }
    '-ReportInclude' { $state.ReportInclude += $args[++$i]; continue }
    default { continue }
  }
}
if (-not $reportPath) { throw 'ReportPath missing' }
Set-Content -LiteralPath $reportPath -Value 'Report Body' -Encoding utf8
if ($resultsPath) {
  Set-Content -LiteralPath $resultsPath -Value 'RSL BODY' -Encoding utf8
}
exit 0
'@
    Set-Content -LiteralPath $stubScript -Value $stubContent -Encoding utf8
    $optionsLauncher = Join-Path $TestDrive 'labviewcli-options.cmd'
    Set-Content -LiteralPath $optionsLauncher -Value "@echo off`npwsh -NoLogo -NoProfile -File ""$stubScript"" %*" -Encoding ascii
    $launcher = Join-Path $TestDrive 'labviewcli-stub.cmd'
    Set-Content -LiteralPath $launcher -Value "@echo off`npwsh -NoLogo -NoProfile -File ""$stubScript"" %*" -Encoding ascii

    $outputRoot = Join-Path $TestDrive 'results-options'
    $result = & $script:scriptPath `
      -ConfigPath $configPath `
      -OutputRoot $outputRoot `
      -ReportSaveType 'HTML' `
      -CaptureResultsFile `
      -LabVIEWCLIPath $optionsLauncher `
      -ConfigPassword 'secret' `
      -ReportSort 'VI' `
      -ReportInclude @('FAILED','SKIPPED') `
      -PassThru

    $cliLog = Join-Path $result.runDir 'vi-analyzer-cli.log'
    (Get-Content -LiteralPath $cliLog -Raw) | Should -Match '-ConfigPassword secret'
    (Get-Content -LiteralPath $cliLog -Raw) | Should -Match '-ReportSort VI'
    (Get-Content -LiteralPath $cliLog -Raw) | Should -Match '-ReportInclude FAILED'
    Test-Path -LiteralPath $result.resultsPath -PathType Leaf | Should -BeTrue
    (Get-Content -LiteralPath $result.resultsPath -Raw).Trim() | Should -Be 'RSL BODY'
  }

  It 'captures version mismatch errors from the report' {
    $configPath = Join-Path $TestDrive 'task-version.viancfg'
    Set-Content -LiteralPath $configPath -Value '<VIAnalyzer></VIAnalyzer>' -Encoding utf8

    $stubScript = Join-Path $TestDrive 'labviewcli-version.ps1'
    $stubContent = @'
$reportPath = $null
for ($i = 0; $i -lt $args.Length; $i++) {
  if ($args[$i] -eq '-ReportPath') { $reportPath = $args[++$i]; break }
}
if (-not $reportPath) { throw 'ReportPath missing' }
Set-Content -LiteralPath $reportPath -Value @(
  'Testing Errors',
  '',
  'VI Not Loadable',
  'Base.vi	C:\repo\Base.vi	Error 1125.  This VI is saved in a LabVIEW version newer than the one you are using.',
  ''
) -Encoding utf8
exit 0
'@
    Set-Content -LiteralPath $stubScript -Value $stubContent -Encoding utf8
    $launcher = Join-Path $TestDrive 'labviewcli-version.cmd'
    Set-Content -LiteralPath $launcher -Value "@echo off`npwsh -NoLogo -NoProfile -File ""$stubScript"" %*" -Encoding ascii

    $result = & $script:scriptPath `
      -ConfigPath $configPath `
      -LabVIEWCLIPath $launcher `
      -OutputRoot (Join-Path $TestDrive 'results-version') `
      -LabVIEWVersion 2023 `
      -Bitness 64 `
      -PassThru

    $result.versionMismatchCount | Should -Be 1
    $result.versionMismatches[0].path | Should -Be 'C:\repo\Base.vi'
    $result.versionMismatches[0].analyzerVersion | Should -Be 2023
    $result.versionMismatches[0].analyzerBitness | Should -Be 64
  }

  It 'throws when LabVIEWCLI returns non-zero exit code' {
    $configPath = Join-Path $TestDrive 'task.viancfg'
    Set-Content -LiteralPath $configPath -Value '<VIAnalyzer></VIAnalyzer>' -Encoding utf8

    $failStub = Join-Path $TestDrive 'labviewcli-fail.ps1'
    $failContent = @"
param(
  [string]`$OperationName,
  [string]`$ConfigPath,
  [string]`$ReportPath,
  [string]`$ReportSaveType,
  [string]`$ResultsPath,
  [Parameter(ValueFromRemainingArguments = `$true)]
  [string[]]`$Remaining
)
exit 5
"@
    Set-Content -LiteralPath $failStub -Value $failContent -Encoding utf8
    $failLauncher = Join-Path $TestDrive 'labviewcli-fail.cmd'
    Set-Content -LiteralPath $failLauncher -Value "@echo off`npwsh -NoLogo -NoProfile -File ""$failStub"" %*" -Encoding ascii

    {
      & $script:scriptPath `
        -ConfigPath $configPath `
        -LabVIEWCLIPath $failLauncher `
        -OutputRoot (Join-Path $TestDrive 'fail-results')
    } | Should -Throw '*exit code 5*'
  }

  It 'surfaces analyzer-specific error codes' {
    $configPath = Join-Path $TestDrive 'task-14217.viancfg'
    Set-Content -LiteralPath $configPath -Value '<VIAnalyzer></VIAnalyzer>' -Encoding utf8

    $failStub = Join-Path $TestDrive 'labviewcli-14217.ps1'
    $failContent = @"
param()
exit 14217
"@
    Set-Content -LiteralPath $failStub -Value $failContent -Encoding utf8
    $fail14217Launcher = Join-Path $TestDrive 'labviewcli-14217.cmd'
    Set-Content -LiteralPath $fail14217Launcher -Value "@echo off`npwsh -NoLogo -NoProfile -File ""$failStub"" %*" -Encoding ascii

    {
      & $script:scriptPath `
        -ConfigPath $configPath `
        -LabVIEWCLIPath $fail14217Launcher `
        -OutputRoot (Join-Path $TestDrive 'fail-14217')
    } | Should -Throw '*project-based analyzer configs*'
  }

  It 'resolves structured config files referencing folders' {
    $targetFolder = Join-Path $TestDrive 'targets-folder'
    New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null
    $configJson = @{
      schema = 'vi-analyzer/config@v1'
      targetType = 'folder'
      targetPath = $targetFolder
    } | ConvertTo-Json -Depth 3
    $configPath = Join-Path $TestDrive 'structured.viancfg'
    Set-Content -LiteralPath $configPath -Value $configJson -Encoding utf8

    $stubScript = Join-Path $TestDrive 'labviewcli-structured.ps1'
    $stubContent = @'
$reportPath = $null
for ($i = 0; $i -lt $args.Length; $i++) {
  if ($args[$i] -eq '-ReportPath') { $reportPath = $args[++$i]; break }
}
if (-not $reportPath) { throw 'ReportPath missing' }
Set-Content -LiteralPath $reportPath -Value 'structured report' -Encoding utf8
exit 0
'@
    Set-Content -LiteralPath $stubScript -Value $stubContent -Encoding utf8
    $launcher = Join-Path $TestDrive 'labviewcli-structured.cmd'
    Set-Content -LiteralPath $launcher -Value "@echo off`npwsh -NoLogo -NoProfile -File ""$stubScript"" %*" -Encoding ascii

    $result = & $script:scriptPath `
      -ConfigPath $configPath `
      -LabVIEWCLIPath $launcher `
      -OutputRoot (Join-Path $TestDrive 'results-structured') `
      -PassThru

    $result | Should -Not -BeNullOrEmpty
    $result.configSourcePath | Should -Be ((Resolve-Path -LiteralPath $configPath).Path)
    $result.configPath | Should -Be ((Resolve-Path -LiteralPath $targetFolder).Path)
  }

  It 'treats test failure exit code 3 as fatal' {
    $configPath = Join-Path $TestDrive 'task-testfail.viancfg'
    Set-Content -LiteralPath $configPath -Value '<VIAnalyzer></VIAnalyzer>' -Encoding utf8

    $stubScript = Join-Path $TestDrive 'labviewcli-testfail.ps1'
    $stubContent = @'
$reportPath = $null
for ($i = 0; $i -lt $args.Length; $i++) {
  if ($args[$i] -eq '-ReportPath') { $reportPath = $args[++$i]; break }
}
if (-not $reportPath) { throw 'ReportPath missing' }
Set-Content -LiteralPath $reportPath -Value @(
  'Failed Tests (sorted by VI)',
  '',
  'MissingInProjectCLI.vi (C:\Examples\MissingInProjectCLI.vi)',
  "Diagram Size`tBlock diagram too wide."
) -Encoding utf8
exit 3
'@
    Set-Content -LiteralPath $stubScript -Value $stubContent -Encoding utf8
    $launcher = Join-Path $TestDrive 'labviewcli-testfail.cmd'
    Set-Content -LiteralPath $launcher -Value "@echo off`npwsh -NoLogo -NoProfile -File ""$stubScript"" %*" -Encoding ascii

    {
      & $script:scriptPath `
        -ConfigPath $configPath `
        -LabVIEWCLIPath $launcher `
        -OutputRoot (Join-Path $TestDrive 'results-testfail')
    } | Should -Throw '*MissingInProjectCLI.vi*'
  }
}
