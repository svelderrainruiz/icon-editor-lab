#Requires -Version 7.0
#Requires -Modules Pester

param()

Describe 'DevMode stage timing summary' -Tag 'DevMode','Stages' {
  It 'aggregates average, min, and max durations per stage' {
    $repoRoot = Join-Path $TestDrive 'stage-repo'
    New-Item -ItemType Directory -Path $repoRoot -Force | Out-Null

    $telemetryDir = Join-Path $repoRoot 'tests/results/_agent/icon-editor/dev-mode-run'
    New-Item -ItemType Directory -Path $telemetryDir -Force | Out-Null

    $run1 = [pscustomobject]@{
      stages = @(
        [pscustomobject]@{
          name = 'enable-addtoken-2025-64'
          durationSeconds = 1.0
          status = 'ok'
        },
        [pscustomobject]@{
          name = 'enable-prepare-2025-64'
          durationSeconds = 2.0
          status = 'ok'
        }
      )
    }

    $run2 = [pscustomobject]@{
      stages = @(
        [pscustomobject]@{
          name = 'enable-addtoken-2025-64'
          durationSeconds = 3.0
          status = 'ok'
        },
        [pscustomobject]@{
          name = 'enable-prepare-2025-64'
          durationSeconds = 4.0
          status = 'ok'
        },
        [pscustomobject]@{
          name = 'disable-close-2025-64'
          durationSeconds = 5.0
          status = 'ok'
        }
      )
    }

    $run1 | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $telemetryDir 'dev-mode-run-1.json') -Encoding utf8
    $run2 | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $telemetryDir 'dev-mode-run-2.json') -Encoding utf8

    $env:WORKSPACE_ROOT = $repoRoot

    $summaryScript = Join-Path $PSScriptRoot 'Summarize-DevModeStages.ps1'
    pwsh -NoLogo -NoProfile -File $summaryScript | Out-Null

    $summaryPath = Join-Path $repoRoot 'tests/results/_agent/icon-editor/dev-mode-stage-summary.json'
    Test-Path -LiteralPath $summaryPath | Should -BeTrue

    $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json

    $enableAdd = $summary.Stages | Where-Object { $_.Name -eq 'enable-addtoken-2025-64' }
    $enablePrep = $summary.Stages | Where-Object { $_.Name -eq 'enable-prepare-2025-64' }
    $disableClose = $summary.Stages | Where-Object { $_.Name -eq 'disable-close-2025-64' }

    $enableAdd | Should -Not -BeNullOrEmpty
    $enablePrep | Should -Not -BeNullOrEmpty
    $disableClose | Should -Not -BeNullOrEmpty

    $enableAdd[0].Count | Should -Be 2
    $enableAdd[0].AverageSeconds | Should -Be 2.0
    $enableAdd[0].MinSeconds | Should -Be 1.0
    $enableAdd[0].MaxSeconds | Should -Be 3.0

    $enablePrep[0].Count | Should -Be 2
    $enablePrep[0].AverageSeconds | Should -Be 3.0
    $enablePrep[0].MinSeconds | Should -Be 2.0
    $enablePrep[0].MaxSeconds | Should -Be 4.0

    $disableClose[0].Count | Should -Be 1
    $disableClose[0].AverageSeconds | Should -Be 5.0
    $disableClose[0].MinSeconds | Should -Be 5.0
    $disableClose[0].MaxSeconds | Should -Be 5.0
  }

  It 'handles many runs without failing' {
    $repoRoot = Join-Path $TestDrive 'stage-repo-many'
    New-Item -ItemType Directory -Path $repoRoot -Force | Out-Null

    $telemetryDir = Join-Path $repoRoot 'tests/results/_agent/icon-editor/dev-mode-run'
    New-Item -ItemType Directory -Path $telemetryDir -Force | Out-Null

    for ($i = 1; $i -le 100; $i++) {
      $run = [pscustomobject]@{
        stages = @(
          [pscustomobject]@{
            name = 'enable-addtoken-2025-64'
            durationSeconds = 1.0 + ($i * 0.01)
            status = 'ok'
          },
          [pscustomobject]@{
            name = 'enable-prepare-2025-64'
            durationSeconds = 2.0 + ($i * 0.01)
            status = 'ok'
          }
        )
      }
      $run | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $telemetryDir ("dev-mode-run-{0}.json" -f $i)) -Encoding utf8
    }

    $env:WORKSPACE_ROOT = $repoRoot

    $summaryScript = Join-Path $PSScriptRoot 'Summarize-DevModeStages.ps1'
    pwsh -NoLogo -NoProfile -File $summaryScript | Out-Null

    $summaryPath = Join-Path $repoRoot 'tests/results/_agent/icon-editor/dev-mode-stage-summary.json'
    Test-Path -LiteralPath $summaryPath | Should -BeTrue

    $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    $enableAdd = $summary.Stages | Where-Object { $_.Name -eq 'enable-addtoken-2025-64' }
    $enableAdd | Should -Not -BeNullOrEmpty
    $enableAdd[0].Count | Should -Be 100
  }
}

