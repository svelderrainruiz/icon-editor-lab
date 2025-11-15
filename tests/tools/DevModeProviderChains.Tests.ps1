#Requires -Version 7.0
#Requires -Modules Pester

param()

Describe 'DevMode provider chains' -Tag 'DevMode','ProviderChains' {
  It 'summarizes pure and hybrid provider chains per RunId' {
    $repoRoot = Join-Path $TestDrive 'chains-repo'
    New-Item -ItemType Directory -Path $repoRoot -Force | Out-Null

    $telemetryDir = Join-Path $repoRoot 'tests/results/_agent/icon-editor/dev-mode-run'
    New-Item -ItemType Directory -Path $telemetryDir -Force | Out-Null

    @(
      # run-real-only: all stages under Real -> pure Real chain
      [pscustomobject]@{
        runId     = 'run-real-only'
        provider  = 'Real'
        operation = 'enable-addtoken-2025-64'
        status    = 'succeeded'
      },
      [pscustomobject]@{
        runId     = 'run-real-only'
        provider  = 'Real'
        operation = 'enable-prepare-2025-64'
        status    = 'succeeded'
      },
      [pscustomobject]@{
        runId     = 'run-real-only'
        provider  = 'Real'
        operation = 'Compare'
        status    = 'succeeded'
      },
      # run-hybrid: Real for addtoken, XCliSim for prepare, Simulation for compare
      [pscustomobject]@{
        runId     = 'run-hybrid'
        provider  = 'Real'
        operation = 'enable-addtoken-2025-64'
        status    = 'succeeded'
      },
      [pscustomobject]@{
        runId     = 'run-hybrid'
        provider  = 'XCliSim'
        operation = 'enable-prepare-2025-64'
        status    = 'succeeded'
      },
      [pscustomobject]@{
        runId     = 'run-hybrid'
        provider  = 'Simulation'
        operation = 'Compare'
        status    = 'failed'
      },
      # run-xclisim-only: all stages under XCliSim -> pure XCliSim chain
      [pscustomobject]@{
        runId     = 'run-xclisim-only'
        provider  = 'XCliSim'
        operation = 'enable-addtoken-2025-64'
        status    = 'succeeded'
      },
      [pscustomobject]@{
        runId     = 'run-xclisim-only'
        provider  = 'XCliSim'
        operation = 'enable-prepare-2025-64'
        status    = 'succeeded'
      },
      [pscustomobject]@{
        runId     = 'run-xclisim-only'
        provider  = 'XCliSim'
        operation = 'Compare'
        status    = 'succeeded'
      }
    ) | ForEach-Object -Begin { $i = 1 } -Process {
      $_ | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $telemetryDir ("dev-mode-run-{0}.json" -f $i)) -Encoding utf8
      $i++
    }

    $env:WORKSPACE_ROOT = $repoRoot

    $script = Join-Path $PSScriptRoot 'Summarize-DevModeProviderChains.ps1'
    pwsh -NoLogo -NoProfile -File $script | Out-Null

    $summaryPath = Join-Path $repoRoot 'tests/results/_agent/icon-editor/dev-mode-provider-chains.json'
    Test-Path -LiteralPath $summaryPath | Should -BeTrue

    $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json

    $summary.TotalRuns | Should -Be 3

    $byChain = $summary.ByProviderChain
    $byChain | Should -Not -BeNullOrEmpty

    $realChain   = $byChain | Where-Object { $_.ProviderChain -eq 'Real' }
    $xcliChain   = $byChain | Where-Object { $_.ProviderChain -eq 'XCliSim' }
    $hybridChain = $byChain | Where-Object { $_.ProviderChain -eq 'Real+XCliSim+Simulation' }

    $realChain   | Should -Not -BeNullOrEmpty
    $xcliChain   | Should -Not -BeNullOrEmpty
    $hybridChain | Should -Not -BeNullOrEmpty

    $realChain[0].TotalRuns   | Should -Be 1
    $realChain[0].Succeeded   | Should -Be 1
    $realChain[0].Failed      | Should -Be 0

    $xcliChain[0].TotalRuns   | Should -Be 1
    $xcliChain[0].Succeeded   | Should -Be 1
    $xcliChain[0].Failed      | Should -Be 0

    $hybridChain[0].TotalRuns | Should -Be 1
    $hybridChain[0].Succeeded | Should -Be 0
    $hybridChain[0].Failed    | Should -Be 1

    # Verify per-run classification as well.
    $runReal   = $summary.Runs | Where-Object { $_.RunId -eq 'run-real-only' }
    $runHybrid = $summary.Runs | Where-Object { $_.RunId -eq 'run-hybrid' }
    $runXcli   = $summary.Runs | Where-Object { $_.RunId -eq 'run-xclisim-only' }

    $runReal[0].ProviderChain   | Should -Be 'Real'
    $runReal[0].Outcome         | Should -Be 'succeeded'

    $runXcli[0].ProviderChain   | Should -Be 'XCliSim'
    $runXcli[0].Outcome         | Should -Be 'succeeded'

    $runHybrid[0].ProviderChain | Should -Be 'Real+XCliSim+Simulation'
    $runHybrid[0].Outcome       | Should -Be 'failed'
  }
}

