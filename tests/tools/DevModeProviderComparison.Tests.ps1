#Requires -Version 7.0
#Requires -Modules Pester

param()

Describe 'DevMode provider comparisons' -Tag 'DevMode','Providers' {
  It 'summarizes provider outcomes per RunId and operation' {
    $repoRoot = Join-Path $TestDrive 'provider-repo'
    New-Item -ItemType Directory -Path $repoRoot -Force | Out-Null

    $modulePath = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path 'src/tools/icon-editor/IconEditorDevMode.psm1'
    Import-Module $modulePath -Force

    $env:WORKSPACE_ROOT = $repoRoot

    $runId = 'run-provider-compare-1'

    foreach ($provider in 'Real','Simulation','XCliSim') {
      $env:ICONEDITORLAB_PROVIDER = $provider
      $env:ICONEDITORLAB_RUN_ID = $runId

      $context = Initialize-IconEditorDevModeTelemetry -Mode 'enable' -RepoRoot $repoRoot -IconEditorRoot $repoRoot -Versions 2025 -Bitness 64 -Operation 'BuildPackage'

      if ($provider -eq 'Real') {
        Complete-IconEditorDevModeTelemetry -Context $context -Status 'succeeded'
      } elseif ($provider -eq 'Simulation') {
        Complete-IconEditorDevModeTelemetry -Context $context -Status 'failed' -Error 'Simulated failure for provider=Simulation.'
      } else {
        $errorText = @"
Dev-mode simulation via x-cli for script 'AddTokenToLabVIEW.ps1' exited with code 2.
[x-cli] labview-devmode: partial failure for stage 'enable-addtoken-2025-64' (simulated, recoverable).
"@
        Complete-IconEditorDevModeTelemetry -Context $context -Status 'degraded' -Error $errorText
      }
    }

    Remove-Item Env:ICONEDITORLAB_PROVIDER -ErrorAction SilentlyContinue
    Remove-Item Env:ICONEDITORLAB_RUN_ID -ErrorAction SilentlyContinue

    $summaryScript = Join-Path $PSScriptRoot 'Summarize-DevModeProviders.ps1'
    pwsh -NoLogo -NoProfile -File $summaryScript | Out-Null

    $summaryPath = Join-Path $repoRoot 'tests/results/_agent/icon-editor/dev-mode-provider-summary.json'
    Test-Path -LiteralPath $summaryPath | Should -BeTrue

    $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    $summary.Comparisons.Count | Should -Be 1

    $comp = $summary.Comparisons[0]
    $comp.RunId     | Should -Be $runId
    $comp.Operation | Should -Be 'BuildPackage'

    $providers = $comp.Providers
    $providers.Count | Should -Be 3

    ($providers | Where-Object { $_.Provider -eq 'Real' }).Status      | Should -Be 'succeeded'
    ($providers | Where-Object { $_.Provider -eq 'Simulation' }).Status | Should -Be 'failed'
    ($providers | Where-Object { $_.Provider -eq 'XCliSim' }).Status    | Should -Be 'degraded'
  }

  It 'exposes provider summary path in learning snippet' {
    $repoRoot = Join-Path $TestDrive 'provider-repo-snippet'
    New-Item -ItemType Directory -Path $repoRoot -Force | Out-Null

    $invDir = Join-Path $repoRoot 'tools/x-cli-develop/temp_telemetry/labview-devmode'
    New-Item -ItemType Directory -Path $invDir -Force | Out-Null

    $invPath = Join-Path $invDir 'invocations.jsonl'
    [pscustomobject]@{
      Kind        = 'labview-devmode'
      Mode        = 'enable'
      Operation   = 'OpSnippet'
      LvVersion   = '2025'
      Bitness     = '64'
      LvaddonRoot = 'C:\fake\lvaddon-root'
      Script      = 'Tooling/PrepareIESource.vi'
      Args        = @('arg1')
    } | ConvertTo-Json -Depth 4 -Compress | Set-Content -LiteralPath $invPath -Encoding utf8

    $providerSummaryDir = Join-Path $repoRoot 'tests/results/_agent/icon-editor'
    New-Item -ItemType Directory -Path $providerSummaryDir -Force | Out-Null
    $providerSummaryPath = Join-Path $providerSummaryDir 'dev-mode-provider-summary.json'
    '{}' | Set-Content -LiteralPath $providerSummaryPath -Encoding utf8

    $env:WORKSPACE_ROOT = $repoRoot

    $snippetScript = Join-Path $PSScriptRoot 'New-LvAddonLearningSnippet.ps1'
    pwsh -NoLogo -NoProfile -File $snippetScript -MaxRecords 5 | Out-Null

    $snippetPath = Join-Path $repoRoot 'tests/results/_agent/icon-editor/xcli-learning-snippet.json'
    Test-Path -LiteralPath $snippetPath | Should -BeTrue

    $snippet = Get-Content -LiteralPath $snippetPath -Raw | ConvertFrom-Json
    $snippet.ProviderSummaryPath | Should -Be $providerSummaryPath
  }
}

