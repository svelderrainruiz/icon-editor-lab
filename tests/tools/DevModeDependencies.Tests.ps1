#Requires -Version 7.0
#Requires -Modules Pester

param()

Describe 'DevMode cross-operation dependency summary' -Tag 'DevMode','Dependencies' {
  It 'classifies BuildPackage runs based on Compare success per provider' {
    $repoRoot = Join-Path $TestDrive 'deps-repo'
    New-Item -ItemType Directory -Path $repoRoot -Force | Out-Null

    $telemetryDir = Join-Path $repoRoot 'tests/results/_agent/icon-editor/dev-mode-run'
    New-Item -ItemType Directory -Path $telemetryDir -Force | Out-Null

    @(
      # Compare succeeded under provider XCliSim
      [pscustomobject]@{
        schema           = 'icon-editor/dev-mode-run@v1'
        runId            = 'run-compare-1'
        provider         = 'XCliSim'
        operation        = 'Compare'
        status           = 'succeeded'
      },
      # BuildPackage succeeded under provider XCliSim (dependency satisfied)
      [pscustomobject]@{
        schema           = 'icon-editor/dev-mode-run@v1'
        runId            = 'run-build-1'
        provider         = 'XCliSim'
        operation        = 'BuildPackage'
        status           = 'succeeded'
      },
      # BuildPackage succeeded under provider Real (no matching Compare success)
      [pscustomobject]@{
        schema           = 'icon-editor/dev-mode-run@v1'
        runId            = 'run-build-2'
        provider         = 'Real'
        operation        = 'BuildPackage'
        status           = 'succeeded'
      },
      # BuildPackage failed under provider XCliSim (dependency satisfied but still failed)
      [pscustomobject]@{
        schema           = 'icon-editor/dev-mode-run@v1'
        runId            = 'run-build-3'
        provider         = 'XCliSim'
        operation        = 'BuildPackage'
        status           = 'failed'
      },
      # BuildPackage failed under provider Other (no matching Compare success)
      [pscustomobject]@{
        schema           = 'icon-editor/dev-mode-run@v1'
        runId            = 'run-build-4'
        provider         = 'Other'
        operation        = 'BuildPackage'
        status           = 'failed'
      }
    ) | ForEach-Object -Begin { $i = 1 } -Process {
      $_ | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $telemetryDir ("dev-mode-run-{0}.json" -f $i)) -Encoding utf8
      $i++
    }

    $env:WORKSPACE_ROOT = $repoRoot

    $script = Join-Path $PSScriptRoot 'Summarize-DevModeDependencies.ps1'
    pwsh -NoLogo -NoProfile -File $script | Out-Null

    $summaryPath = Join-Path $repoRoot 'tests/results/_agent/icon-editor/dev-mode-dependency-summary.json'
    Test-Path -LiteralPath $summaryPath | Should -BeTrue

    $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json

    $summary.Dependencies.Count | Should -Be 1
    $dep = $summary.Dependencies[0]

    $dep.Operation  | Should -Be 'BuildPackage'
    $dep.DependsOn  | Should -Be 'Compare'
    $dep.TotalRuns  | Should -Be 4

    $dep.SucceededWithDependency    | Should -Be 1   # XCliSim success with Compare success
    $dep.SucceededWithoutDependency | Should -Be 1   # Real success with no matching Compare
    $dep.FailedWithDependency       | Should -Be 1   # XCliSim failure despite Compare success
    $dep.FailedWithoutDependency    | Should -Be 1   # Other failure with no matching Compare
  }

  It 'classifies BuildPackage dependencies using real telemetry for XCliSim' {
    $repoRoot = Join-Path $TestDrive 'deps-repo-e2e'
    New-Item -ItemType Directory -Path $repoRoot -Force | Out-Null

    $modulePath = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path 'src/tools/icon-editor/IconEditorDevMode.psm1'
    Import-Module $modulePath -Force

    $env:WORKSPACE_ROOT = $repoRoot

    # Compare succeeded under XCliSim
    $env:ICONEDITORLAB_PROVIDER = 'XCliSim'
    $compareCtx = Initialize-IconEditorDevModeTelemetry -Mode 'enable' -RepoRoot $repoRoot -IconEditorRoot $repoRoot -Versions 2021 -Bitness 32 -Operation 'Compare'
    Complete-IconEditorDevModeTelemetry -Context $compareCtx -Status 'succeeded'

    # BuildPackage succeeded under XCliSim (dependency satisfied)
    $env:ICONEDITORLAB_PROVIDER = 'XCliSim'
    $build1Ctx = Initialize-IconEditorDevModeTelemetry -Mode 'enable' -RepoRoot $repoRoot -IconEditorRoot $repoRoot -Versions 2021 -Bitness 32 -Operation 'BuildPackage'
    Complete-IconEditorDevModeTelemetry -Context $build1Ctx -Status 'succeeded'

    # BuildPackage succeeded under Real (no matching Compare success)
    $env:ICONEDITORLAB_PROVIDER = 'Real'
    $build2Ctx = Initialize-IconEditorDevModeTelemetry -Mode 'enable' -RepoRoot $repoRoot -IconEditorRoot $repoRoot -Versions 2021 -Bitness 32 -Operation 'BuildPackage'
    Complete-IconEditorDevModeTelemetry -Context $build2Ctx -Status 'succeeded'

    # BuildPackage failed under XCliSim (dependency satisfied but still failed)
    $env:ICONEDITORLAB_PROVIDER = 'XCliSim'
    $build3Ctx = Initialize-IconEditorDevModeTelemetry -Mode 'enable' -RepoRoot $repoRoot -IconEditorRoot $repoRoot -Versions 2021 -Bitness 32 -Operation 'BuildPackage'
    Complete-IconEditorDevModeTelemetry -Context $build3Ctx -Status 'failed' -Error 'Simulated failure for BuildPackage under XCliSim.'

    # BuildPackage failed under Other (no matching Compare success)
    $env:ICONEDITORLAB_PROVIDER = 'Other'
    $build4Ctx = Initialize-IconEditorDevModeTelemetry -Mode 'enable' -RepoRoot $repoRoot -IconEditorRoot $repoRoot -Versions 2021 -Bitness 32 -Operation 'BuildPackage'
    Complete-IconEditorDevModeTelemetry -Context $build4Ctx -Status 'failed' -Error 'Simulated failure for BuildPackage under Other.'

    Remove-Item Env:ICONEDITORLAB_PROVIDER -ErrorAction SilentlyContinue

    $script = Join-Path $PSScriptRoot 'Summarize-DevModeDependencies.ps1'
    pwsh -NoLogo -NoProfile -File $script | Out-Null

    $summaryPath = Join-Path $repoRoot 'tests/results/_agent/icon-editor/dev-mode-dependency-summary.json'
    Test-Path -LiteralPath $summaryPath | Should -BeTrue

    $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json

    $summary.Dependencies.Count | Should -Be 1
    $dep = $summary.Dependencies[0]

    $dep.Operation  | Should -Be 'BuildPackage'
    $dep.DependsOn  | Should -Be 'Compare'
    $dep.TotalRuns  | Should -Be 4

    $dep.SucceededWithDependency    | Should -Be 1
    $dep.SucceededWithoutDependency | Should -Be 1
    $dep.FailedWithDependency       | Should -Be 1
    $dep.FailedWithoutDependency    | Should -Be 1
  }
}
