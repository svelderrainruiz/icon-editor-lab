#Requires -Version 7.0
#Requires -Modules Pester

param()

Describe 'MipScenarioHelpers helpers' -Tag 'Mip','Helpers' {
  BeforeAll {
    $modulePath = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'src/tools/icon-editor/MipScenarioHelpers.psm1'
    Import-Module $modulePath -Force
  }

  It 'parses LUnit report path from simulated output' {
    $lines = @(
      '[LUnit] 42 tests, 1 failure, 0 errors.',
      'LUnit: 1 test failed',
      'Some other log line before report path',
      'Report written to: C:\fake\lunit\lunit_results.xml'
    )

    $path = Get-ReportPathFromOutput -Lines $lines
    $path | Should -Be 'C:\fake\lunit\lunit_results.xml'
  }

  It 'emits a dev-mode warning for MIP analyzer failures' {
    $root = Join-Path $TestDrive 'mip-analyzer'
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    $analyzerDir = Join-Path $root 'vi-analyzer-mip'
    New-Item -ItemType Directory -Path $analyzerDir -Force | Out-Null

    $jsonPath = Join-Path $analyzerDir 'vi-analyzer.json'
    @{
      devModeLikelyDisabled = $true
      failureCount          = 1
    } | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $jsonPath -Encoding utf8

    $msg = Write-AnalyzerDevModeWarning -AnalyzerDir $analyzerDir -Prefix '[5]' -PassThru
    $msg | Should -Match 'development mode is likely disabled'
  }

  It 'reads MissingInProject missing VIs from a report' {
    $root = Join-Path $TestDrive 'mip-report-root'
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    $reportPath = Join-Path $root 'mip-report.json'
    $report = [ordered]@{
      schema  = 'icon-editor/report@v1'
      kind    = 'missing-in-project'
      label   = 'mip-test'
      summary = '2 missing VIs'
      extra   = [ordered]@{
        missingTargets = @(
          [ordered]@{ path  = 'C:\src\Missing1.vi' },
          [ordered]@{ viPath = 'C:\src\Missing2.vi' }
        )
      }
    }
    $report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $reportPath -Encoding utf8

    $missing = Get-MissingInProjectMissingViPaths -ReportPath $reportPath
    $missing.Count | Should -Be 2
    $missing | Should -Contain 'C:\src\Missing1.vi'
    $missing | Should -Contain 'C:\src\Missing2.vi'
  }

  It 'reads LUnit failed tests from a unit-test report' {
    $root = Join-Path $TestDrive 'lunit-report-root'
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    $reportPath = Join-Path $root 'unit-report.json'
    $report = [ordered]@{
      schema = 'icon-editor/report@v1'
      kind   = 'unit-tests'
      label  = 'unit-labtest'
      extra  = [ordered]@{
        failedTests = @(
          [ordered]@{ name = 'Test_AddToken';  viPath = 'C:\src\tests\Test_AddToken.vi' },
          [ordered]@{ name = 'Test_PreparePPL'; viPath = $null },
          'Test_LegacyHelper'
        )
      }
    }
    $report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $reportPath -Encoding utf8

    $failed = Get-LUnitFailedTestsFromReport -ReportPath $reportPath
    $failed.Count | Should -Be 3

    ($failed | Where-Object { $_.Name -eq 'Test_AddToken' }).Path     | Should -Be 'C:\src\tests\Test_AddToken.vi'
    ($failed | Where-Object { $_.Name -eq 'Test_PreparePPL' }).Count  | Should -Be 1
    ($failed | Where-Object { $_.Name -eq 'Test_LegacyHelper' }).Count | Should -Be 1
  }
}
