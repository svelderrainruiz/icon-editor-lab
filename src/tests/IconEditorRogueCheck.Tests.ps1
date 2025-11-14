#Requires -Version 7.0

$modulePath = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'tools' 'icon-editor' 'IconEditorDevMode.psm1'
Import-Module $modulePath -Force

function New-RogueStubRepo {
  $repo = Join-Path $TestDrive ([Guid]::NewGuid().ToString())
  $toolsDir = Join-Path $repo 'tools'
  New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
  $detectPath = Join-Path $toolsDir 'Detect-RogueLV.ps1'
@'
[CmdletBinding()]
param(
  [string]$ResultsDir,
  [int]$LookBackSeconds,
  [switch]$FailOnRogue,
  [switch]$AppendToStepSummary,
  [switch]$Quiet,
  [int]$RetryCount,
  [int]$RetryDelaySeconds,
  [string]$OutputPath
)
$payload = @{
  rogue = @{
    labview = @(1111)
    lvcompare = @()
  }
}
$json = $payload | ConvertTo-Json -Depth 4
$json | Set-Content -LiteralPath $OutputPath -Encoding utf8
exit 3
'@ | Set-Content -LiteralPath $detectPath -Encoding utf8
  return $repo
}

Describe 'Invoke-IconEditorRogueCheck auto-close' -Tag 'IconEditor','Rogue' {
  BeforeEach {
    Remove-Item Env:LABVIEWCLI_RESULTS_ROOT -ErrorAction SilentlyContinue
    Remove-Item Env:LV_NOTICE_DIR -ErrorAction SilentlyContinue
    $script:closeCalls = 0
  }

  It 'attempts Close-IconEditorLabVIEW and reruns detection' {
    $repo = Join-Path $TestDrive 'repo'
    $toolsDir = Join-Path $repo 'tools'
    New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
    $detectPath = Join-Path $toolsDir 'Detect-RogueLV.ps1'
@'
[CmdletBinding()]
param(
  [string]$ResultsDir,
  [int]$LookBackSeconds,
  [switch]$FailOnRogue,
  [switch]$AppendToStepSummary,
  [switch]$Quiet,
  [int]$RetryCount,
  [int]$RetryDelaySeconds,
  [string]$OutputPath
)
$statePath = Join-Path (Split-Path -Parent $OutputPath) 'stub-state.txt'
$count = 0
if (Test-Path -LiteralPath $statePath) {
  $count = [int](Get-Content -LiteralPath $statePath -Raw)
}
$count++
$count | Set-Content -LiteralPath $statePath
'{}' | Set-Content -LiteralPath $OutputPath -Encoding utf8
if ($count -lt 2) { exit 3 } else { exit 0 }
'@ | Set-Content -LiteralPath $detectPath -Encoding utf8

    Mock Close-IconEditorLabVIEW { $script:closeCalls++ } -ModuleName IconEditorDevMode

    $runRoot = Join-Path $TestDrive 'run-root'
    $result = Invoke-IconEditorRogueCheck -RepoRoot $repo -Stage 'unit-test' -AutoClose -FailOnRogue -RunRoot $runRoot -Versions @(2021) -Bitness @(64)

    $script:closeCalls | Should -Be 1
    $result.ExitCode | Should -Be 0
    [Environment]::GetEnvironmentVariable('LABVIEWCLI_RESULTS_ROOT','Process') | Should -BeNullOrEmpty
    [Environment]::GetEnvironmentVariable('LV_NOTICE_DIR','Process') | Should -BeNullOrEmpty
  }
}

Describe 'Invoke-LabVIEWRogueSweep graceful cleanup' -Tag 'IconEditor','Rogue' {
  BeforeEach {
    Remove-Item Env:LABVIEWCLI_RESULTS_ROOT -ErrorAction SilentlyContinue
    Remove-Item Env:LV_NOTICE_DIR -ErrorAction SilentlyContinue
    $script:autoCloseCalls = 0
    $script:stopCalls = 0
  }

  It 'uses Invoke-IconEditorRogueCheck and avoids Stop-Process by default' {
    $repo = New-RogueStubRepo
    $runRoot = Join-Path $TestDrive 'run-root'
    Mock Invoke-IconEditorRogueCheck { $script:autoCloseCalls++ } -ModuleName IconEditorDevMode
    Mock Stop-Process { throw "Stop-Process should not be called" } -ModuleName IconEditorDevMode

    $result = Invoke-LabVIEWRogueSweep -RepoRoot $repo -Reason 'unit' -RunRoot $runRoot -Versions @(2021) -Bitness @(64)

    $script:autoCloseCalls | Should -Be 1
    $result.rogueLabVIEW.Count | Should -BeGreaterThan 0
  }

  It 'falls back to Stop-Process when force terminate is allowed' {
    $repo = New-RogueStubRepo
    $runRoot = Join-Path $TestDrive 'run-root-force'
    Mock Invoke-IconEditorRogueCheck { } -ModuleName IconEditorDevMode
    Mock Stop-Process { $script:stopCalls++ } -ModuleName IconEditorDevMode

    $result = Invoke-LabVIEWRogueSweep -RepoRoot $repo -Reason 'unit-force' -RunRoot $runRoot -Versions @(2021) -Bitness @(64) -ForceTerminateOnFailure

    $script:stopCalls | Should -BeGreaterThan 0
    $result.rogueLabVIEW.Count | Should -BeGreaterThan 0
  }
}

AfterAll {
  Remove-Item Env:LABVIEWCLI_RESULTS_ROOT -ErrorAction SilentlyContinue
  Remove-Item Env:LV_NOTICE_DIR -ErrorAction SilentlyContinue
  Remove-Module IconEditorDevMode -Force -ErrorAction SilentlyContinue
}
