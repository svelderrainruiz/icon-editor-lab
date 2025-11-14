#Requires -Version 7.0

$modulePath = Join-Path $PSScriptRoot '..' '..' 'local-ci' 'windows' 'modules' 'LabVIEWCliIsolation.psm1'
if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
    throw "LabVIEWCliIsolation module not found at $modulePath"
}
Import-Module $modulePath -Force

function Invoke-MockProviderSession {
  param(
    [string]$RunRoot,
    [string]$ProviderLabel
  )

  $state = Enter-LabVIEWCliIsolation -RunRoot $RunRoot -Label $ProviderLabel
  $pidTrackerDir = Join-Path $state.ResultsRoot '_cli' '_agent'
  New-Item -ItemType Directory -Path $pidTrackerDir -Force | Out-Null
  $pidTrackerPath = Join-Path $pidTrackerDir 'labview-pid.json'
  @{
    pid = Get-Random -Minimum 1000 -Maximum 9999
    running = $true
  } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $pidTrackerPath -Encoding utf8

  $operationDir = Join-Path $state.ResultsRoot '_cli'
  New-Item -ItemType Directory -Path $operationDir -Force | Out-Null
  $operationLog = Join-Path $operationDir 'operation-events.ndjson'
  "{ ""provider"": ""$ProviderLabel"", ""timestamp"": ""$(Get-Date -Format o)"" }" |
    Add-Content -LiteralPath $operationLog -Encoding utf8

  Exit-LabVIEWCliIsolation -Isolation $state
  return $state.SessionMetadataPath
}

Describe 'LabVIEW CLI isolation helpers' -Tag 'LocalCI','LabVIEWCli' {
  AfterEach {
    Remove-Item Env:LABVIEWCLI_RESULTS_ROOT -ErrorAction SilentlyContinue
    Remove-Item Env:LV_NOTICE_DIR -ErrorAction SilentlyContinue
  }

  It 'sets environment variables and restores them on exit' {
    $env:LABVIEWCLI_RESULTS_ROOT = 'original'
    $env:LV_NOTICE_DIR = 'orig-notice'
    $runRoot = Join-Path $TestDrive 'run'
    $state = Enter-LabVIEWCliIsolation -RunRoot $runRoot -Label 'unit-test'
    $resultsRoot = [Environment]::GetEnvironmentVariable('LABVIEWCLI_RESULTS_ROOT','Process')
    $noticeDir = [Environment]::GetEnvironmentVariable('LV_NOTICE_DIR','Process')
    $resultsRoot | Should -Match 'unit-test'
    Test-Path -LiteralPath (Join-Path $resultsRoot 'tests/results') | Should -BeTrue
    Test-Path -LiteralPath $noticeDir | Should -BeTrue
    $state.SessionMetadataPath | Should -Not -BeNullOrEmpty
    Test-Path -LiteralPath $state.SessionMetadataPath -PathType Leaf | Should -BeTrue
    $initial = Get-Content -LiteralPath $state.SessionMetadataPath -Raw | ConvertFrom-Json
    $initial.label | Should -Be 'unit-test'
    $initial.paths.sessionRoot | Should -Be $state.SessionRoot
    Exit-LabVIEWCliIsolation -Isolation $state
    $final = Get-Content -LiteralPath $state.SessionMetadataPath -Raw | ConvertFrom-Json
    $final.stoppedAt | Should -Not -BeNullOrEmpty
    [Environment]::GetEnvironmentVariable('LABVIEWCLI_RESULTS_ROOT','Process') | Should -Be 'original'
    [Environment]::GetEnvironmentVariable('LV_NOTICE_DIR','Process') | Should -Be 'orig-notice'
  }

  It 'creates directories when run root is missing' {
    $runRoot = Join-Path $TestDrive 'fresh' 'run'
    $state = Enter-LabVIEWCliIsolation -RunRoot $runRoot -Label 'fresh'
    Test-Path -LiteralPath $runRoot | Should -BeTrue
    Test-Path -LiteralPath $state.SessionMetadataPath -PathType Leaf | Should -BeTrue
    Exit-LabVIEWCliIsolation -Isolation $state
  }
}

function Invoke-MockProviderSession {
  param(
    [string]$RunRoot,
    [string]$ProviderLabel
  )

  $state = Enter-LabVIEWCliIsolation -RunRoot $RunRoot -Label $ProviderLabel
  $pidTrackerDir = Join-Path $state.ResultsRoot '_cli' '_agent'
  New-Item -ItemType Directory -Path $pidTrackerDir -Force | Out-Null
  $pidTrackerPath = Join-Path $pidTrackerDir 'labview-pid.json'
  @{
    pid = Get-Random -Minimum 1000 -Maximum 9999
    running = $true
  } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $pidTrackerPath -Encoding utf8

  $operationDir = Join-Path $state.ResultsRoot '_cli'
  New-Item -ItemType Directory -Path $operationDir -Force | Out-Null
  $operationLog = Join-Path $operationDir 'operation-events.ndjson'
  "{ ""provider"": ""$ProviderLabel"", ""timestamp"": ""$(Get-Date -Format o)"" }" |
    Add-Content -LiteralPath $operationLog -Encoding utf8

  Exit-LabVIEWCliIsolation -Isolation $state
  return $state.SessionMetadataPath
}

Describe 'LabVIEW CLI isolation sequences' -Tag 'LocalCI','LabVIEWCli' {

  It 'handles sequential runs of the same provider (g-cli -> g-cli)' {
    $runRoot = Join-Path $TestDrive 'seq-gg'
    $first = Invoke-MockProviderSession -RunRoot $runRoot -ProviderLabel 'g-cli'
    $second = Invoke-MockProviderSession -RunRoot $runRoot -ProviderLabel 'g-cli'

    $firstMeta = Get-Content -LiteralPath $first -Raw | ConvertFrom-Json
    $secondMeta = Get-Content -LiteralPath $second -Raw | ConvertFrom-Json
    $firstMeta.label | Should -Be 'g-cli'
    $secondMeta.label | Should -Be 'g-cli'
    [datetimeoffset]$firstMeta.stoppedAt | Should -BeLessThan ([datetimeoffset]$secondMeta.startedAt)
  }

  It 'handles sequential LabVIEWCLI sessions (labviewcli -> labviewcli)' {
    $runRoot = Join-Path $TestDrive 'seq-ll'
    $metas = @()
    $metas += Invoke-MockProviderSession -RunRoot $runRoot -ProviderLabel 'labviewcli'
    $metas += Invoke-MockProviderSession -RunRoot $runRoot -ProviderLabel 'labviewcli'
    foreach ($metaPath in $metas) {
      $meta = Get-Content -LiteralPath $metaPath -Raw | ConvertFrom-Json
      $meta.label | Should -Be 'labviewcli'
      Test-Path -LiteralPath (Join-Path (Split-Path -Parent $metaPath) 'tests' 'results' '_cli' '_agent' 'labview-pid.json') | Should -BeTrue
    }
  }

  It 'handles mixed providers (labviewcli -> vipm-gcli)' {
    $runRoot = Join-Path $TestDrive 'seq-lv'
    $firstMetaPath = Invoke-MockProviderSession -RunRoot $runRoot -ProviderLabel 'labviewcli'
    $secondMetaPath = Invoke-MockProviderSession -RunRoot $runRoot -ProviderLabel 'vipm-gcli'

    $firstMeta = Get-Content -LiteralPath $firstMetaPath -Raw | ConvertFrom-Json
    $secondMeta = Get-Content -LiteralPath $secondMetaPath -Raw | ConvertFrom-Json
    $firstMeta.label | Should -Be 'labviewcli'
    $secondMeta.label | Should -Be 'vipm-gcli'
    [Environment]::GetEnvironmentVariable('LABVIEWCLI_RESULTS_ROOT','Process') | Should -BeNullOrEmpty
    [Environment]::GetEnvironmentVariable('LV_NOTICE_DIR','Process') | Should -BeNullOrEmpty
  }

  It 'handles g-cli -> vipmcli transitions' {
    $runRoot = Join-Path $TestDrive 'seq-gv'
    $gcliMeta = Invoke-MockProviderSession -RunRoot $runRoot -ProviderLabel 'g-cli'
    $vipmcliMeta = Invoke-MockProviderSession -RunRoot $runRoot -ProviderLabel 'vipmcli'
    (Get-Content -LiteralPath $gcliMeta -Raw | ConvertFrom-Json).label | Should -Be 'g-cli'
    (Get-Content -LiteralPath $vipmcliMeta -Raw | ConvertFrom-Json).label | Should -Be 'vipmcli'
  }

  It 'handles labviewcli -> vipmcli transitions' {
    $runRoot = Join-Path $TestDrive 'seq-lv2'
    $labviewMeta = Invoke-MockProviderSession -RunRoot $runRoot -ProviderLabel 'labviewcli'
    $vipmMeta = Invoke-MockProviderSession -RunRoot $runRoot -ProviderLabel 'vipmcli'
    (Get-Content -LiteralPath $labviewMeta -Raw | ConvertFrom-Json).label | Should -Be 'labviewcli'
    (Get-Content -LiteralPath $vipmMeta -Raw | ConvertFrom-Json).label | Should -Be 'vipmcli'
  }

  It 'handles vipmcli -> g-cli transitions' {
    $runRoot = Join-Path $TestDrive 'seq-vg'
    $vipmMeta = Invoke-MockProviderSession -RunRoot $runRoot -ProviderLabel 'vipmcli'
    $gcliMeta = Invoke-MockProviderSession -RunRoot $runRoot -ProviderLabel 'g-cli'
    (Get-Content -LiteralPath $vipmMeta -Raw | ConvertFrom-Json).label | Should -Be 'vipmcli'
    (Get-Content -LiteralPath $gcliMeta -Raw | ConvertFrom-Json).label | Should -Be 'g-cli'
  }
}

AfterAll {
  Remove-Module LabVIEWCliIsolation -Force -ErrorAction SilentlyContinue
}
