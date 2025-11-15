#Requires -Version 7.0
#Requires -Modules Pester

param()

Describe 'Labview dev-mode flakiness summary' -Tag 'DevMode','Flakiness' {
  It 'marks scenarios with mixed outcomes as flaky' {
    $root = Join-Path $TestDrive 'flaky-workspace'
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    $devModeDir = Join-Path $root 'tools/x-cli-develop/temp_telemetry/labview-devmode'
    New-Item -ItemType Directory -Path $devModeDir -Force | Out-Null

    $invPath = Join-Path $devModeDir 'invocations.jsonl'
    @(
      # Flaky scenario: sometimes succeeded, sometimes failed
      [pscustomobject]@{
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'enable-addtoken-2025-64'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'AddTokenToLabVIEW.ps1'
        Scenario    = 'retry-success.enable-addtoken-2021-32.v1'
        ExitCode    = 0
      },
      [pscustomobject]@{
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'enable-addtoken-2025-64'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'AddTokenToLabVIEW.ps1'
        Scenario    = 'retry-success.enable-addtoken-2021-32.v1'
        ExitCode    = 1
      },
      [pscustomobject]@{
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'enable-addtoken-2025-64'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'AddTokenToLabVIEW.ps1'
        Scenario    = 'retry-success.enable-addtoken-2021-32.v1'
        ExitCode    = 0
      },
      # Stable scenario: always succeeds
      [pscustomobject]@{
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'enable-prepare-2025-64'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'PrepareIESource.ps1'
        Scenario    = 'happy-path'
        ExitCode    = 0
      },
      [pscustomobject]@{
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'enable-prepare-2025-64'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'PrepareIESource.ps1'
        Scenario    = 'happy-path'
        ExitCode    = 0
      }
    ) | ForEach-Object {
      $_ | ConvertTo-Json -Depth 4 -Compress
    } | Set-Content -LiteralPath $invPath -Encoding utf8

    $env:WORKSPACE_ROOT = $root

    $summaryScript = Join-Path $PSScriptRoot 'Summarize-LabviewDevmodeFlakiness.ps1'
    pwsh -NoLogo -NoProfile -File $summaryScript | Out-Null

    $summaryPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-devmode-flakiness.json'
    Test-Path -LiteralPath $summaryPath | Should -BeTrue

    $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    $summary.TotalRecords | Should -Be 5

    $byScenario = $summary.ByScenario
    $byScenario | Should -Not -BeNullOrEmpty

    $timeoutSoft = $byScenario | Where-Object { $_.Scenario -eq 'retry-success.enable-addtoken-2021-32.v1' }
    $happyPath   = $byScenario | Where-Object { $_.Scenario -eq 'happy-path' }

    $timeoutSoft | Should -Not -BeNullOrEmpty
    $happyPath   | Should -Not -BeNullOrEmpty

    $timeoutSoft[0].Total   | Should -Be 3
    $timeoutSoft[0].IsFlaky | Should -BeTrue

    $happyPath[0].Total     | Should -Be 2
    $happyPath[0].IsFlaky   | Should -BeFalse
  }

  It 'captures outcome sequences for temporal trend inspection' {
    $root = Join-Path $TestDrive 'flaky-sequence'
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    $devModeDir = Join-Path $root 'tools/x-cli-develop/temp_telemetry/labview-devmode'
    New-Item -ItemType Directory -Path $devModeDir -Force | Out-Null

    $invPath = Join-Path $devModeDir 'invocations.jsonl'
    @(
      [pscustomobject]@{
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'enable-addtoken-2025-64'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'AddTokenToLabVIEW.ps1'
        Scenario    = 'flaky-sample'
        ExitCode    = 0
      },
      [pscustomobject]@{
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'enable-addtoken-2025-64'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'AddTokenToLabVIEW.ps1'
        Scenario    = 'flaky-sample'
        ExitCode    = 1
      },
      [pscustomobject]@{
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'enable-addtoken-2025-64'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'AddTokenToLabVIEW.ps1'
        Scenario    = 'flaky-sample'
        ExitCode    = 2
      }
    ) | ForEach-Object {
      $_ | ConvertTo-Json -Depth 4 -Compress
    } | Set-Content -LiteralPath $invPath -Encoding utf8

    $env:WORKSPACE_ROOT = $root

    $summaryScript = Join-Path $PSScriptRoot 'Summarize-LabviewDevmodeFlakiness.ps1'
    pwsh -NoLogo -NoProfile -File $summaryScript | Out-Null

    $summaryPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-devmode-flakiness.json'
    Test-Path -LiteralPath $summaryPath | Should -BeTrue

    $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json

    $flaky = $summary.ByScenario | Where-Object { $_.Scenario -eq 'flaky-sample' }
    $flaky | Should -Not -BeNullOrEmpty

    $seq = $flaky[0].OutcomeSequence
    $seq.Count | Should -Be 3
    $seq[0]    | Should -Be 'succeeded'
    $seq[1]    | Should -Be 'failed'
    $seq[2]    | Should -Be 'degraded'
  }
}
