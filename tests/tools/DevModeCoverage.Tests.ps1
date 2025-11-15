#Requires -Version 7.0
#Requires -Modules Pester

param()

Describe 'Labview dev-mode coverage summary' -Tag 'DevMode','Coverage' {
  It 'computes scenario coverage and gaps per operation/version/bitness' {
    $root = Join-Path $TestDrive 'coverage-workspace'
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    $devModeDir = Join-Path $root 'tools/x-cli-develop/temp_telemetry/labview-devmode'
    New-Item -ItemType Directory -Path $devModeDir -Force | Out-Null

    $invPath = Join-Path $devModeDir 'invocations.jsonl'
    @(
      # enable-addtoken 2025 x64 with happy-path, timeout, and timeout-soft variants
      [pscustomobject]@{
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'enable-addtoken-2025-64'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'AddTokenToLabVIEW.ps1'
        Scenario    = 'happy-path'
      },
      [pscustomobject]@{
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'enable-addtoken-2025-64'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'AddTokenToLabVIEW.ps1'
        Scenario    = 'timeout'
      },
      [pscustomobject]@{
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'enable-addtoken-2025-64'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'AddTokenToLabVIEW.ps1'
        Scenario    = 'timeout-soft.enable-addtoken-2025-64.v1'
      },
      # enable-prepare 2025 x64 with only happy-path
      [pscustomobject]@{
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'enable-prepare-2025-64'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'PrepareIESource.ps1'
        Scenario    = 'happy-path'
      }
    ) | ForEach-Object {
      $_ | ConvertTo-Json -Depth 4 -Compress
    } | Set-Content -LiteralPath $invPath -Encoding utf8

    $env:WORKSPACE_ROOT = $root

    $script = Join-Path $PSScriptRoot 'Summarize-LabviewDevmodeCoverage.ps1'
    pwsh -NoLogo -NoProfile -File $script | Out-Null

    $summaryPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-devmode-coverage.json'
    Test-Path -LiteralPath $summaryPath | Should -BeTrue

    $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    $summary.TotalRecords | Should -Be 4

    $entries = $summary.ByOperationVersionBitness
    $entries.Count | Should -Be 2

    $addToken = $entries | Where-Object { $_.Operation -eq 'enable-addtoken-2025-64' -and $_.LvVersion -eq '2025' -and $_.Bitness -eq '64' }
    $addToken | Should -Not -BeNullOrEmpty
    $addToken[0].Total | Should -Be 3

    $families = $addToken[0].ScenarioFamilies
    $families | Should -Not -BeNullOrEmpty

    ($families | Where-Object { $_.Family -eq 'happy-path' }).Count   | Should -Be 1
    ($families | Where-Object { $_.Family -eq 'timeout' }).Count       | Should -Be 1
    ($families | Where-Object { $_.Family -eq 'timeout-soft' }).Count  | Should -Be 1

    $missing = $addToken[0].FamiliesMissing
    $missing | Should -Contain 'rogue'
    $missing | Should -Contain 'partial'
    $missing | Should -Contain 'partial+timeout-soft'
    $missing | Should -Contain 'retry-success'
    $missing | Should -Contain 'lunit'
    $missing | Should -Not -Contain 'happy-path'
    $missing | Should -Not -Contain 'timeout'
    $missing | Should -Not -Contain 'timeout-soft'

    $prepare = $entries | Where-Object { $_.Operation -eq 'enable-prepare-2025-64' -and $_.LvVersion -eq '2025' -and $_.Bitness -eq '64' }
    $prepare | Should -Not -BeNullOrEmpty
    $prepare[0].Total | Should -Be 1

    $prepFamilies = $prepare[0].ScenarioFamilies
    ($prepFamilies | Where-Object { $_.Family -eq 'happy-path' }).Count | Should -Be 1

    $prepMissing = $prepare[0].FamiliesMissing
    $prepMissing | Should -Contain 'timeout'
    $prepMissing | Should -Contain 'rogue'
    $prepMissing | Should -Contain 'lunit'
  }

  It 'honors DesiredScenarioFamilies overrides' {
    $root = Join-Path $TestDrive 'coverage-desired'
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    $devModeDir = Join-Path $root 'tools/x-cli-develop/temp_telemetry/labview-devmode'
    New-Item -ItemType Directory -Path $devModeDir -Force | Out-Null

    $invPath = Join-Path $devModeDir 'invocations.jsonl'
    @(
      [pscustomobject]@{
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'enable-addtoken-2026-32'
        LvVersion   = '2026'
        Bitness     = '32'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'AddTokenToLabVIEW.ps1'
        Scenario    = 'timeout-soft.enable-addtoken-2026-32.v1'
      }
    ) | ForEach-Object {
      $_ | ConvertTo-Json -Depth 4 -Compress
    } | Set-Content -LiteralPath $invPath -Encoding utf8

    $env:WORKSPACE_ROOT = $root

    $script = Join-Path $PSScriptRoot 'Summarize-LabviewDevmodeCoverage.ps1'
    & $script -DesiredScenarioFamilies @('happy-path','timeout-soft') | Out-Null

    $summaryPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-devmode-coverage.json'
    Test-Path -LiteralPath $summaryPath | Should -BeTrue

    $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    $summary.TotalRecords | Should -Be 1

    $entry = $summary.ByOperationVersionBitness[0]
    $entry.Operation | Should -Be 'enable-addtoken-2026-32'
    $entry.LvVersion | Should -Be '2026'
    $entry.Bitness   | Should -Be '32'

    $summary.DesiredScenarioFamilies | Should -Contain 'happy-path'
    $summary.DesiredScenarioFamilies | Should -Contain 'timeout-soft'

    $missing = $entry.FamiliesMissing
    $missing | Should -Contain 'happy-path'
    $missing | Should -Not -Contain 'timeout-soft'
  }
}
