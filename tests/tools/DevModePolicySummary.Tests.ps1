#Requires -Version 7.0
#Requires -Modules Pester

param()

Describe 'DevMode policy summary' -Tag 'DevMode','Policies' {
  It 'aggregates run outcomes by lvAddonRootMode' {
    $repoRoot = Join-Path $TestDrive 'policy-repo'
    New-Item -ItemType Directory -Path $repoRoot -Force | Out-Null

    $telemetryDir = Join-Path $repoRoot 'tests/results/_agent/icon-editor/dev-mode-run'
    New-Item -ItemType Directory -Path $telemetryDir -Force | Out-Null

    @(
      # Strict: one failed, one succeeded
      [pscustomobject]@{
        schema          = 'icon-editor/dev-mode-run@v1'
        runId           = 'run-strict-1'
        operation       = 'BuildPackage'
        status          = 'failed'
        lvAddonRootMode = 'Strict'
      },
      [pscustomobject]@{
        schema          = 'icon-editor/dev-mode-run@v1'
        runId           = 'run-strict-2'
        operation       = 'BuildPackage'
        status          = 'succeeded'
        lvAddonRootMode = 'Strict'
      },
      # Relaxed: one degraded, one succeeded
      [pscustomobject]@{
        schema          = 'icon-editor/dev-mode-run@v1'
        runId           = 'run-relaxed-1'
        operation       = 'BuildPackage'
        status          = 'degraded'
        lvAddonRootMode = 'Relaxed'
      },
      [pscustomobject]@{
        schema          = 'icon-editor/dev-mode-run@v1'
        runId           = 'run-relaxed-2'
        operation       = 'Compare'
        status          = 'succeeded'
        lvAddonRootMode = 'Relaxed'
      },
      # No mode recorded
      [pscustomobject]@{
        schema    = 'icon-editor/dev-mode-run@v1'
        runId     = 'run-nomode-1'
        operation = 'BuildPackage'
        status    = 'succeeded'
      }
    ) | ForEach-Object -Begin { $i = 1 } -Process {
      $_ | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $telemetryDir ("dev-mode-run-{0}.json" -f $i)) -Encoding utf8
      $i++
    }

    $env:WORKSPACE_ROOT = $repoRoot

    $summaryScript = Join-Path $PSScriptRoot 'Summarize-DevModePolicies.ps1'
    pwsh -NoLogo -NoProfile -File $summaryScript | Out-Null

    $summaryPath = Join-Path $repoRoot 'tests/results/_agent/icon-editor/dev-mode-policy-summary.json'
    Test-Path -LiteralPath $summaryPath | Should -BeTrue

    $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json

    $summary.Policies.Count | Should -Be 3

    $strict   = $summary.Policies | Where-Object { $_.Policy -eq 'Strict' }
    $relaxed  = $summary.Policies | Where-Object { $_.Policy -eq 'Relaxed' }
    $noneMode = $summary.Policies | Where-Object { $_.Policy -eq '<none>' }

    $strict   | Should -Not -BeNullOrEmpty
    $relaxed  | Should -Not -BeNullOrEmpty
    $noneMode | Should -Not -BeNullOrEmpty

    $strict[0].TotalRuns  | Should -Be 2
    $relaxed[0].TotalRuns | Should -Be 2
    $noneMode[0].TotalRuns | Should -Be 1

    $strictStatuses = $strict[0].Statuses
    ($strictStatuses | Where-Object { $_.Status -eq 'failed' }).Count    | Should -Be 1
    ($strictStatuses | Where-Object { $_.Status -eq 'succeeded' }).Count | Should -Be 1

    $relaxedStatuses = $relaxed[0].Statuses
    ($relaxedStatuses | Where-Object { $_.Status -eq 'degraded' }).Count | Should -Be 1
    ($relaxedStatuses | Where-Object { $_.Status -eq 'succeeded' }).Count | Should -Be 1

    $strict[0].Operations  | Should -Contain 'BuildPackage'
    $relaxed[0].Operations | Should -Contain 'BuildPackage'
    $relaxed[0].Operations | Should -Contain 'Compare'
  }
}

