#Requires -Version 7.0
#Requires -Modules Pester

param()

Describe 'LvAddon learning loop data collections' -Tag 'DevMode','LvAddon','Learning' {
  It 'writes a summary JSON from x-cli invocations' {
    $root = Join-Path $TestDrive 'workspace'
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    $devModeDir = Join-Path $root 'tools/x-cli-develop/temp_telemetry/labview-devmode'
    New-Item -ItemType Directory -Path $devModeDir -Force | Out-Null

    $invPath = Join-Path $devModeDir 'invocations.jsonl'
    @(
      [pscustomobject]@{
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'Enable'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'Tooling/PrepareIESource.vi'
        Args        = @('arg1','arg2')
      },
      [pscustomobject]@{
        Kind        = 'labview-devmode'
        Mode        = 'disable'
        Operation   = 'Disable'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'Tooling/RestoreIESource.vi'
        Args        = @('arg3')
      }
    ) | ForEach-Object {
      $_ | ConvertTo-Json -Depth 4 -Compress
    } | Set-Content -LiteralPath $invPath -Encoding utf8

    $env:WORKSPACE_ROOT = $root

    $summaryScript = Join-Path $PSScriptRoot 'Summarize-LabviewDevmodeLogs.ps1'
    pwsh -NoLogo -NoProfile -File $summaryScript | Out-Null

    $summaryPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-devmode-summary.json'
    Test-Path -LiteralPath $summaryPath | Should -BeTrue

    $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    $summary.TotalRecords | Should -Be 2
    $summary.ByOperation.Operation | Should -Contain 'Enable'
    $summary.ByOperation.Operation | Should -Contain 'Disable'
  }

  It 'writes and reads a learning snippet JSON' {
    $root = Join-Path $TestDrive 'workspace-snippet'
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    $devModeDir = Join-Path $root 'tools/x-cli-develop/temp_telemetry/labview-devmode'
    New-Item -ItemType Directory -Path $devModeDir -Force | Out-Null

    $invPath = Join-Path $devModeDir 'invocations.jsonl'
    [pscustomobject]@{
      Kind        = 'labview-devmode'
      Mode        = 'enable'
      Operation   = 'Enable'
      LvVersion   = '2025'
      Bitness     = '64'
      LvaddonRoot = 'C:\fake\lvaddon-root'
      Script      = 'Tooling/PrepareIESource.vi'
      Args        = @('arg1','arg2')
    } | ConvertTo-Json -Depth 4 -Compress | Set-Content -LiteralPath $invPath -Encoding utf8

    $env:WORKSPACE_ROOT = $root

    $snippetScript = Join-Path $PSScriptRoot 'New-LvAddonLearningSnippet.ps1'
    pwsh -NoLogo -NoProfile -File $snippetScript -MaxRecords 5 | Out-Null

    $snippetPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-learning-snippet.json'
    Test-Path -LiteralPath $snippetPath | Should -BeTrue

    $snippet = Get-Content -LiteralPath $snippetPath -Raw | ConvertFrom-Json
    $snippet.SampleRecords.Count | Should -Be 1

    $rec = $snippet.SampleRecords[0]
    $rec.Mode | Should -Be 'enable'
    $rec.Operation | Should -Be 'Enable'
    $rec.LvVersion | Should -Be '2025'
    $rec.Bitness | Should -Be '64'
    $rec.LvAddonRoot | Should -Be 'C:\fake\lvaddon-root'
    $rec.Script | Should -Be 'Tooling/PrepareIESource.vi'
    $rec.Args | Should -Contain 'arg1'
  }

  It 'includes VI History run summary path in snippet when available' {
    $root = Join-Path $TestDrive 'workspace-snippet-vihistory'
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    $devModeDir = Join-Path $root 'tools/x-cli-develop/temp_telemetry/labview-devmode'
    New-Item -ItemType Directory -Path $devModeDir -Force | Out-Null

    $invPath = Join-Path $devModeDir 'invocations.jsonl'
    [pscustomobject]@{
      Kind        = 'labview-devmode'
      Mode        = 'enable'
      Operation   = 'Enable'
      LvVersion   = '2025'
      Bitness     = '64'
      LvaddonRoot = 'C:\fake\lvaddon-root'
      Script      = 'Tooling/PrepareIESource.vi'
      Args        = @('arg1')
    } | ConvertTo-Json -Depth 4 -Compress | Set-Content -LiteralPath $invPath -Encoding utf8

    $viHistoryRoot = Join-Path $root 'tests/results/_agent/vi-history'
    New-Item -ItemType Directory -Path $viHistoryRoot -Force | Out-Null
    $viHistorySummaryPath = Join-Path $viHistoryRoot 'vi-history-run-summary.json'
    @{} | ConvertTo-Json -Depth 2 | Set-Content -LiteralPath $viHistorySummaryPath -Encoding utf8

    $env:WORKSPACE_ROOT = $root

    $snippetScript = Join-Path $PSScriptRoot 'New-LvAddonLearningSnippet.ps1'
    pwsh -NoLogo -NoProfile -File $snippetScript -MaxRecords 5 | Out-Null

    $snippetPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-learning-snippet.json'
    Test-Path -LiteralPath $snippetPath | Should -BeTrue

    $snippet = Get-Content -LiteralPath $snippetPath -Raw | ConvertFrom-Json
    $snippet.VIHistoryRunSummaryPath | Should -Be (Resolve-Path -LiteralPath $viHistorySummaryPath).ProviderPath
  }

  It 'includes VI History family and VIPM install summary paths in snippet when available' {
    $root = Join-Path $TestDrive 'workspace-snippet-vihistory-vipm'
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    $devModeDir = Join-Path $root 'tools/x-cli-develop/temp_telemetry/labview-devmode'
    New-Item -ItemType Directory -Path $devModeDir -Force | Out-Null

    $invPath = Join-Path $devModeDir 'invocations.jsonl'
    [pscustomobject]@{
      Kind        = 'labview-devmode'
      Mode        = 'enable'
      Operation   = 'Enable'
      LvVersion   = '2025'
      Bitness     = '64'
      LvaddonRoot = 'C:\fake\lvaddon-root'
      Script      = 'Tooling/PrepareIESource.vi'
      Args        = @('arg1')
    } | ConvertTo-Json -Depth 4 -Compress | Set-Content -LiteralPath $invPath -Encoding utf8

    $viHistoryRoot = Join-Path $root 'tests/results/_agent/vi-history'
    New-Item -ItemType Directory -Path $viHistoryRoot -Force | Out-Null
    $viHistoryRunSummaryPath = Join-Path $viHistoryRoot 'vi-history-run-summary.json'
    @{} | ConvertTo-Json -Depth 2 | Set-Content -LiteralPath $viHistoryRunSummaryPath -Encoding utf8
    $viHistoryFamilySummaryPath = Join-Path $viHistoryRoot 'vi-history-family-summary.json'
    @{} | ConvertTo-Json -Depth 2 | Set-Content -LiteralPath $viHistoryFamilySummaryPath -Encoding utf8

    $vipmRoot = Join-Path $root 'tests/results/_agent/icon-editor/vipm-install'
    New-Item -ItemType Directory -Path $vipmRoot -Force | Out-Null
    $vipmSummaryPath = Join-Path $root 'tests/results/_agent/icon-editor/vipm-install-summary.json'
    @{} | ConvertTo-Json -Depth 2 | Set-Content -LiteralPath $vipmSummaryPath -Encoding utf8

    $env:WORKSPACE_ROOT = $root

    $snippetScript = Join-Path $PSScriptRoot 'New-LvAddonLearningSnippet.ps1'
    pwsh -NoLogo -NoProfile -File $snippetScript -MaxRecords 5 | Out-Null

    $snippetPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-learning-snippet.json'
    Test-Path -LiteralPath $snippetPath | Should -BeTrue

    $snippet = Get-Content -LiteralPath $snippetPath -Raw | ConvertFrom-Json
    $snippet.VIHistoryRunSummaryPath    | Should -Be (Resolve-Path -LiteralPath $viHistoryRunSummaryPath).ProviderPath
    $snippet.VIHistoryFamilySummaryPath | Should -Be (Resolve-Path -LiteralPath $viHistoryFamilySummaryPath).ProviderPath
    $snippet.VipmInstallSummaryPath     | Should -Be (Resolve-Path -LiteralPath $vipmSummaryPath).ProviderPath
  }

  It 'honors DevModeDir and InvocationPath overrides' {
    $root = Join-Path $TestDrive 'workspace-overrides'
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    $devModeDir = Join-Path $root 'custom/temp_telemetry/labview-devmode'
    New-Item -ItemType Directory -Path $devModeDir -Force | Out-Null

    $invPath = Join-Path $devModeDir 'invocations.jsonl'
    [pscustomobject]@{
      Kind        = 'labview-devmode'
      Mode        = 'enable'
      Operation   = 'EnableOverride'
      LvVersion   = '2026'
      Bitness     = '32'
      LvaddonRoot = 'C:\override\lvaddon-root'
      Script      = 'Tooling/PrepareIESource.vi'
      Args        = @('ov1')
    } | ConvertTo-Json -Depth 4 -Compress | Set-Content -LiteralPath $invPath -Encoding utf8

    $env:WORKSPACE_ROOT = $root

    $outputPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-learning-snippet.json'
    $snippetScript = Join-Path $PSScriptRoot 'New-LvAddonLearningSnippet.ps1'
    pwsh -NoLogo -NoProfile -File $snippetScript -DevModeDir $devModeDir -InvocationPath $invPath -OutputPath $outputPath | Out-Null

    Test-Path -LiteralPath $outputPath | Should -BeTrue
    $snippet = Get-Content -LiteralPath $outputPath -Raw | ConvertFrom-Json

    $snippet.SourceLogPath | Should -Be (Resolve-Path -LiteralPath $invPath).ProviderPath
    $snippet.SampleRecords.Count | Should -Be 1
    $snippet.SampleRecords[0].Operation | Should -Be 'EnableOverride'
  }

  It 'respects MaxRecords tail selection for snippets' {
    $root = Join-Path $TestDrive 'workspace-tail'
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    $devModeDir = Join-Path $root 'tools/x-cli-develop/temp_telemetry/labview-devmode'
    New-Item -ItemType Directory -Path $devModeDir -Force | Out-Null

    $invPath = Join-Path $devModeDir 'invocations.jsonl'
    @(
      [pscustomobject]@{
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'FirstOp'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'Tooling/PrepareIESource.vi'
        Args        = @()
      },
      [pscustomobject]@{
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'SecondOp'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'Tooling/PrepareIESource.vi'
        Args        = @()
      },
      [pscustomobject]@{
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'ThirdOp'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'Tooling/PrepareIESource.vi'
        Args        = @()
      }
    ) | ForEach-Object {
      $_ | ConvertTo-Json -Depth 4 -Compress
    } | Set-Content -LiteralPath $invPath -Encoding utf8

    $env:WORKSPACE_ROOT = $root

    $snippetScript = Join-Path $PSScriptRoot 'New-LvAddonLearningSnippet.ps1'
    pwsh -NoLogo -NoProfile -File $snippetScript -MaxRecords 2 | Out-Null

    $snippetPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-learning-snippet.json'
    Test-Path -LiteralPath $snippetPath | Should -BeTrue

    $snippet = Get-Content -LiteralPath $snippetPath -Raw | ConvertFrom-Json
    $snippet.SampleRecords.Count | Should -Be 2
    $ops = $snippet.SampleRecords.Operation
    $ops | Should -Contain 'SecondOp'
    $ops | Should -Contain 'ThirdOp'
    $ops | Should -Not -Contain 'FirstOp'
  }

  It 'skips corrupted JSON lines but keeps valid records' {
    $root = Join-Path $TestDrive 'workspace-corrupt'
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    $devModeDir = Join-Path $root 'tools/x-cli-develop/temp_telemetry/labview-devmode'
    New-Item -ItemType Directory -Path $devModeDir -Force | Out-Null

    $invPath = Join-Path $devModeDir 'invocations.jsonl'
    @(
      ([pscustomobject]@{
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'GoodOp'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'Tooling/PrepareIESource.vi'
        Args        = @()
      } | ConvertTo-Json -Depth 4 -Compress)
      # Simulate a truncated JSON line (partial write at EOF).
      '{"Kind":"labview-devmode","Mode":"enable","Operation":"TruncatedOp"'
    ) | Set-Content -LiteralPath $invPath -Encoding utf8

    $env:WORKSPACE_ROOT = $root

    $summaryScript = Join-Path $PSScriptRoot 'Summarize-LabviewDevmodeLogs.ps1'
    pwsh -NoLogo -NoProfile -File $summaryScript | Out-Null

    $summaryPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-devmode-summary.json'
    Test-Path -LiteralPath $summaryPath | Should -BeTrue

    $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    $summary.TotalRecords | Should -Be 1
    $summary.ByOperation.Operation | Should -Contain 'GoodOp'

    $snippetScript = Join-Path $PSScriptRoot 'New-LvAddonLearningSnippet.ps1'
    pwsh -NoLogo -NoProfile -File $snippetScript -MaxRecords 5 | Out-Null

    $snippetPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-learning-snippet.json'
    Test-Path -LiteralPath $snippetPath | Should -BeTrue
    $snippet = Get-Content -LiteralPath $snippetPath -Raw | ConvertFrom-Json
    $snippet.SampleRecords.Count | Should -Be 1
    $snippet.SampleRecords[0].Operation | Should -Be 'GoodOp'
  }

  It 'handles records with missing optional fields' {
    $root = Join-Path $TestDrive 'workspace-missing-fields'
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    $devModeDir = Join-Path $root 'tools/x-cli-develop/temp_telemetry/labview-devmode'
    New-Item -ItemType Directory -Path $devModeDir -Force | Out-Null

    $invPath = Join-Path $devModeDir 'invocations.jsonl'
    @(
      [pscustomobject]@{
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'WithFields'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'Tooling/PrepareIESource.vi'
        Args        = @('a')
      },
      [pscustomobject]@{
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'MissingFields'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'Tooling/PrepareIESource.vi'
      }
    ) | ForEach-Object {
      $_ | ConvertTo-Json -Depth 4 -Compress
    } | Set-Content -LiteralPath $invPath -Encoding utf8

    $env:WORKSPACE_ROOT = $root

    $summaryScript = Join-Path $PSScriptRoot 'Summarize-LabviewDevmodeLogs.ps1'
    pwsh -NoLogo -NoProfile -File $summaryScript | Out-Null

    $summaryPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-devmode-summary.json'
    Test-Path -LiteralPath $summaryPath | Should -BeTrue

    $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    $summary.TotalRecords | Should -Be 2

    $snippetScript = Join-Path $PSScriptRoot 'New-LvAddonLearningSnippet.ps1'
    pwsh -NoLogo -NoProfile -File $snippetScript -MaxRecords 5 | Out-Null

    $snippetPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-learning-snippet.json'
    Test-Path -LiteralPath $snippetPath | Should -BeTrue

    $snippet = Get-Content -LiteralPath $snippetPath -Raw | ConvertFrom-Json
    $snippet.SampleRecords.Count | Should -Be 2

    $missing = $snippet.SampleRecords | Where-Object { $_.Operation -eq 'MissingFields' }
    $missing | Should -Not -BeNullOrEmpty
    $missing[0].LvVersion | Should -Be $null
    $missing[0].Bitness   | Should -Be $null
    $missing[0].Args      | Should -Be $null
  }

  It 'aggregates multiple invocations.jsonl files recursively' {
    $root = Join-Path $TestDrive 'workspace-multi'
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    $devModeRoot = Join-Path $root 'tools/x-cli-develop/temp_telemetry/labview-devmode'
    $run1Dir = Join-Path $devModeRoot 'run1'
    $run2Dir = Join-Path $devModeRoot 'run2'
    New-Item -ItemType Directory -Path $run1Dir -Force | Out-Null
    New-Item -ItemType Directory -Path $run2Dir -Force | Out-Null

    $run1Path = Join-Path $run1Dir 'invocations.jsonl'
    [pscustomobject]@{
      Kind        = 'labview-devmode'
      Mode        = 'enable'
      Operation   = 'Run1Op'
      LvVersion   = '2025'
      Bitness     = '64'
      LvaddonRoot = 'C:\fake\lvaddon-root'
      Script      = 'Tooling/PrepareIESource.vi'
      Args        = @()
    } | ConvertTo-Json -Depth 4 -Compress | Set-Content -LiteralPath $run1Path -Encoding utf8

    $run2Path = Join-Path $run2Dir 'invocations.jsonl'
    @(
      [pscustomobject]@{
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'Run2Op1'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'Tooling/PrepareIESource.vi'
        Args        = @()
      },
      [pscustomobject]@{
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'Run2Op2'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'Tooling/PrepareIESource.vi'
        Args        = @()
      }
    ) | ForEach-Object {
      $_ | ConvertTo-Json -Depth 4 -Compress
    } | Set-Content -LiteralPath $run2Path -Encoding utf8

    $env:WORKSPACE_ROOT = $root

    $summaryScript = Join-Path $PSScriptRoot 'Summarize-LabviewDevmodeLogs.ps1'
    pwsh -NoLogo -NoProfile -File $summaryScript | Out-Null

    $summaryPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-devmode-summary.json'
    Test-Path -LiteralPath $summaryPath | Should -BeTrue

    $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    $summary.TotalRecords | Should -Be 3

    $ops = $summary.ByOperation.Operation
    $ops | Should -Contain 'Run1Op'
    $ops | Should -Contain 'Run2Op1'
    $ops | Should -Contain 'Run2Op2'
  }

  It 'tracks schema versions in summary and snippet' {
    $root = Join-Path $TestDrive 'workspace-schema'
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    $devModeDir = Join-Path $root 'tools/x-cli-develop/temp_telemetry/labview-devmode'
    New-Item -ItemType Directory -Path $devModeDir -Force | Out-Null

    $invPath = Join-Path $devModeDir 'invocations.jsonl'
    @(
      [pscustomobject]@{
        Schema      = 'labview-devmode/v1'
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'SchemaV1Op'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'Tooling/PrepareIESource.vi'
      },
      [pscustomobject]@{
        Schema      = 'labview-devmode/v2'
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'SchemaV2Op'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'Tooling/PrepareIESource.vi'
      },
      [pscustomobject]@{
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'LegacyOp'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'Tooling/PrepareIESource.vi'
      }
    ) | ForEach-Object {
      $_ | ConvertTo-Json -Depth 4 -Compress
    } | Set-Content -LiteralPath $invPath -Encoding utf8

    $env:WORKSPACE_ROOT = $root

    $summaryScript = Join-Path $PSScriptRoot 'Summarize-LabviewDevmodeLogs.ps1'
    pwsh -NoLogo -NoProfile -File $summaryScript | Out-Null

    $summaryPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-devmode-summary.json'
    Test-Path -LiteralPath $summaryPath | Should -BeTrue

    $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    $summary.SchemaVersions | Should -Contain 'labview-devmode/v1'
    $summary.SchemaVersions | Should -Contain 'labview-devmode/v2'
    $summary.SchemaVersions | Should -Contain '<none>'

    $snippetScript = Join-Path $PSScriptRoot 'New-LvAddonLearningSnippet.ps1'
    pwsh -NoLogo -NoProfile -File $snippetScript -MaxRecords 10 | Out-Null

    $snippetPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-learning-snippet.json'
    Test-Path -LiteralPath $snippetPath | Should -BeTrue

    $snippet = Get-Content -LiteralPath $snippetPath -Raw | ConvertFrom-Json
    $snippet.SchemaVersions | Should -Contain 'labview-devmode/v1'
    $snippet.SchemaVersions | Should -Contain 'labview-devmode/v2'
    $snippet.SchemaVersions | Should -Contain '<none>'

    $v1 = $snippet.SampleRecords | Where-Object { $_.Operation -eq 'SchemaV1Op' }
    $v2 = $snippet.SampleRecords | Where-Object { $_.Operation -eq 'SchemaV2Op' }
    $legacy = $snippet.SampleRecords | Where-Object { $_.Operation -eq 'LegacyOp' }

    $v1[0].Schema | Should -Be 'labview-devmode/v1'
    $v2[0].Schema | Should -Be 'labview-devmode/v2'
    $legacy[0].Schema | Should -Be $null
  }

  It 'tolerates additional future fields on records' {
    $root = Join-Path $TestDrive 'workspace-future-fields'
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    $devModeDir = Join-Path $root 'tools/x-cli-develop/temp_telemetry/labview-devmode'
    New-Item -ItemType Directory -Path $devModeDir -Force | Out-Null

    $invPath = Join-Path $devModeDir 'invocations.jsonl'
    [pscustomobject]@{
      Kind        = 'labview-devmode'
      Mode        = 'enable'
      Operation   = 'OpFuture'
      LvVersion   = '2025'
      Bitness     = '64'
      LvaddonRoot = 'C:\fake\lvaddon-root'
      Script      = 'Tooling/PrepareIESource.vi'
      FutureField = 'future-value'
    } | ConvertTo-Json -Depth 4 -Compress | Set-Content -LiteralPath $invPath -Encoding utf8

    $env:WORKSPACE_ROOT = $root

    $summaryScript = Join-Path $PSScriptRoot 'Summarize-LabviewDevmodeLogs.ps1'
    pwsh -NoLogo -NoProfile -File $summaryScript | Out-Null

    $summaryPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-devmode-summary.json'
    Test-Path -LiteralPath $summaryPath | Should -BeTrue

    $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    $summary.TotalRecords | Should -Be 1
    $summary.ByOperation.Operation | Should -Contain 'OpFuture'

    $snippetScript = Join-Path $PSScriptRoot 'New-LvAddonLearningSnippet.ps1'
    pwsh -NoLogo -NoProfile -File $snippetScript -MaxRecords 5 | Out-Null

    $snippetPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-learning-snippet.json'
    Test-Path -LiteralPath $snippetPath | Should -BeTrue

    $snippet = Get-Content -LiteralPath $snippetPath -Raw | ConvertFrom-Json
    $snippet.SampleRecords.Count | Should -Be 1
    $snippet.SampleRecords[0].Operation | Should -Be 'OpFuture'
  }

  It 'groups records by RunId when present' {
    $root = Join-Path $TestDrive 'workspace-runid'
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    $devModeDir = Join-Path $root 'tools/x-cli-develop/temp_telemetry/labview-devmode'
    New-Item -ItemType Directory -Path $devModeDir -Force | Out-Null

    $invPath = Join-Path $devModeDir 'invocations.jsonl'
    @(
      [pscustomobject]@{
        RunId       = 'run-1'
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'Op1'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'Tooling/PrepareIESource.vi'
      },
      [pscustomobject]@{
        RunId       = 'run-1'
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'Op2'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'Tooling/PrepareIESource.vi'
      },
      [pscustomobject]@{
        RunId       = 'run-2'
        Kind        = 'labview-devmode'
        Mode        = 'disable'
        Operation   = 'Op3'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'Tooling/RestoreIESource.vi'
      }
    ) | ForEach-Object {
      $_ | ConvertTo-Json -Depth 4 -Compress
    } | Set-Content -LiteralPath $invPath -Encoding utf8

    $env:WORKSPACE_ROOT = $root

    $summaryScript = Join-Path $PSScriptRoot 'Summarize-LabviewDevmodeLogs.ps1'
    pwsh -NoLogo -NoProfile -File $summaryScript | Out-Null

    $summaryPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-devmode-summary.json'
    Test-Path -LiteralPath $summaryPath | Should -BeTrue

    $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    $summary.TotalRecords | Should -Be 3
    $summary.ByRunId.Count | Should -Be 2

    $run1 = $summary.ByRunId | Where-Object { $_.RunId -eq 'run-1' }
    $run2 = $summary.ByRunId | Where-Object { $_.RunId -eq 'run-2' }

    $run1 | Should -Not -BeNullOrEmpty
    $run1[0].Total | Should -Be 2
    $run1[0].Operations | Should -Contain 'Op1'
    $run1[0].Operations | Should -Contain 'Op2'

    $run2 | Should -Not -BeNullOrEmpty
    $run2[0].Total | Should -Be 1
    $run2[0].Operations | Should -Contain 'Op3'
  }

  It 'handles interleaved RunIds in ByRunId aggregation' {
    $root = Join-Path $TestDrive 'workspace-runid-interleaved'
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    $devModeDir = Join-Path $root 'tools/x-cli-develop/temp_telemetry/labview-devmode'
    New-Item -ItemType Directory -Path $devModeDir -Force | Out-Null

    $invPath = Join-Path $devModeDir 'invocations.jsonl'
    @(
      # Interleave RunIds to simulate concurrent runs writing in parallel
      [pscustomobject]@{
        RunId       = 'run-A'
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'OpA1'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'Tooling/PrepareIESource.vi'
      },
      [pscustomobject]@{
        RunId       = 'run-B'
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'OpB1'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'Tooling/PrepareIESource.vi'
      },
      [pscustomobject]@{
        RunId       = 'run-A'
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'OpA2'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'Tooling/PrepareIESource.vi'
      },
      [pscustomobject]@{
        RunId       = 'run-C'
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'OpC1'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'Tooling/PrepareIESource.vi'
      },
      [pscustomobject]@{
        RunId       = 'run-B'
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'OpB2'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'Tooling/PrepareIESource.vi'
      }
    ) | ForEach-Object {
      $_ | ConvertTo-Json -Depth 4 -Compress
    } | Set-Content -LiteralPath $invPath -Encoding utf8

    $env:WORKSPACE_ROOT = $root

    $summaryScript = Join-Path $PSScriptRoot 'Summarize-LabviewDevmodeLogs.ps1'
    pwsh -NoLogo -NoProfile -File $summaryScript | Out-Null

    $summaryPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-devmode-summary.json'
    Test-Path -LiteralPath $summaryPath | Should -BeTrue

    $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    $summary.TotalRecords | Should -Be 5
    $summary.ByRunId.Count | Should -Be 3

    $runA = $summary.ByRunId | Where-Object { $_.RunId -eq 'run-A' }
    $runB = $summary.ByRunId | Where-Object { $_.RunId -eq 'run-B' }
    $runC = $summary.ByRunId | Where-Object { $_.RunId -eq 'run-C' }

    $runA | Should -Not -BeNullOrEmpty
    $runA[0].Total      | Should -Be 2
    $runA[0].Operations | Should -Contain 'OpA1'
    $runA[0].Operations | Should -Contain 'OpA2'

    $runB | Should -Not -BeNullOrEmpty
    $runB[0].Total      | Should -Be 2
    $runB[0].Operations | Should -Contain 'OpB1'
    $runB[0].Operations | Should -Contain 'OpB2'

    $runC | Should -Not -BeNullOrEmpty
    $runC[0].Total      | Should -Be 1
    $runC[0].Operations | Should -Contain 'OpC1'
  }

  It 'computes per-run outcomes from ExitCodes' {
    $root = Join-Path $TestDrive 'workspace-run-outcomes'
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    $devModeDir = Join-Path $root 'tools/x-cli-develop/temp_telemetry/labview-devmode'
    New-Item -ItemType Directory -Path $devModeDir -Force | Out-Null

    $invPath = Join-Path $devModeDir 'invocations.jsonl'
    @(
      # run-success: all exit codes 0
      [pscustomobject]@{
        RunId       = 'run-success'
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'OpSuccess1'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'Tooling/PrepareIESource.vi'
        ExitCode    = 0
      },
      [pscustomobject]@{
        RunId       = 'run-success'
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'OpSuccess2'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'Tooling/PrepareIESource.vi'
        ExitCode    = 0
      },
      # run-degraded: only partial (2)
      [pscustomobject]@{
        RunId       = 'run-degraded'
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'OpDegraded1'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'Tooling/PrepareIESource.vi'
        ExitCode    = 2
      },
      [pscustomobject]@{
        RunId       = 'run-degraded'
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'OpDegraded2'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'Tooling/PrepareIESource.vi'
        ExitCode    = 2
      },
      # run-failed: at least one hard failure (1)
      [pscustomobject]@{
        RunId       = 'run-failed'
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'OpFailed'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'Tooling/PrepareIESource.vi'
        ExitCode    = 1
      }
    ) | ForEach-Object {
      $_ | ConvertTo-Json -Depth 4 -Compress
    } | Set-Content -LiteralPath $invPath -Encoding utf8

    $env:WORKSPACE_ROOT = $root

    $summaryScript = Join-Path $PSScriptRoot 'Summarize-LabviewDevmodeLogs.ps1'
    pwsh -NoLogo -NoProfile -File $summaryScript | Out-Null

    $summaryPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-devmode-summary.json'
    Test-Path -LiteralPath $summaryPath | Should -BeTrue

    $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json

    $successRun   = $summary.ByRunId | Where-Object { $_.RunId -eq 'run-success' }
    $degradedRun  = $summary.ByRunId | Where-Object { $_.RunId -eq 'run-degraded' }
    $failedRun    = $summary.ByRunId | Where-Object { $_.RunId -eq 'run-failed' }

    $successRun | Should -Not -BeNullOrEmpty
    $degradedRun | Should -Not -BeNullOrEmpty
    $failedRun | Should -Not -BeNullOrEmpty

    $successRun[0].Outcome  | Should -Be 'succeeded'
    $degradedRun[0].Outcome | Should -Be 'degraded'
    $failedRun[0].Outcome   | Should -Be 'failed'
  }

  It 'classifies aborted runs based on ExitCode 130' {
    $root = Join-Path $TestDrive 'workspace-run-aborted'
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    $devModeDir = Join-Path $root 'tools/x-cli-develop/temp_telemetry/labview-devmode'
    New-Item -ItemType Directory -Path $devModeDir -Force | Out-Null

    $invPath = Join-Path $devModeDir 'invocations.jsonl'
    @(
      [pscustomobject]@{
        RunId       = 'run-aborted'
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'OpAbort1'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'Tooling/PrepareIESource.vi'
        ExitCode    = 130
      },
      # mixed with a success exit in the same run
      [pscustomobject]@{
        RunId       = 'run-aborted'
        Kind        = 'labview-devmode'
        Mode        = 'disable'
        Operation   = 'OpAbort2'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'Tooling/RestoreIESource.vi'
        ExitCode    = 0
      }
    ) | ForEach-Object {
      $_ | ConvertTo-Json -Depth 4 -Compress
    } | Set-Content -LiteralPath $invPath -Encoding utf8

    $env:WORKSPACE_ROOT = $root

    $summaryScript = Join-Path $PSScriptRoot 'Summarize-LabviewDevmodeLogs.ps1'
    pwsh -NoLogo -NoProfile -File $summaryScript | Out-Null

    $summaryPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-devmode-summary.json'
    Test-Path -LiteralPath $summaryPath | Should -BeTrue

    $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    $abortedRun = $summary.ByRunId | Where-Object { $_.RunId -eq 'run-aborted' }

    $abortedRun | Should -Not -BeNullOrEmpty
    $abortedRun[0].Outcome   | Should -Be 'aborted'
    $abortedRun[0].ExitCodes | Should -Contain 130
  }

  It 'summarizes scenario config errors across records' {
    $root = Join-Path $TestDrive 'workspace-config-errors'
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    $devModeDir = Join-Path $root 'tools/x-cli-develop/temp_telemetry/labview-devmode'
    New-Item -ItemType Directory -Path $devModeDir -Force | Out-Null

    $invPath = Join-Path $devModeDir 'invocations.jsonl'
    @(
      [pscustomobject]@{
        Kind              = 'labview-devmode'
        Mode              = 'enable'
        Operation         = 'OpCfg1'
        LvVersion         = '2025'
        Bitness           = '64'
        LvaddonRoot       = 'C:\fake\lvaddon-root'
        Script            = 'Tooling/PrepareIESource.vi'
        ExitCode          = 2
        ConfigError       = $true
        ConfigErrorDetail = 'invalid-json'
      },
      [pscustomobject]@{
        Kind              = 'labview-devmode'
        Mode              = 'enable'
        Operation         = 'OpCfg2'
        LvVersion         = '2025'
        Bitness           = '64'
        LvaddonRoot       = 'C:\fake\lvaddon-root'
        Script            = 'Tooling/PrepareIESource.vi'
        ExitCode          = 2
        ConfigError       = $true
        ConfigErrorDetail = 'file-not-found'
      },
      [pscustomobject]@{
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'OpNoCfg'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'Tooling/PrepareIESource.vi'
        ExitCode    = 0
      }
    ) | ForEach-Object {
      $_ | ConvertTo-Json -Depth 4 -Compress
    } | Set-Content -LiteralPath $invPath -Encoding utf8

    $env:WORKSPACE_ROOT = $root

    $summaryScript = Join-Path $PSScriptRoot 'Summarize-LabviewDevmodeLogs.ps1'
    pwsh -NoLogo -NoProfile -File $summaryScript | Out-Null

    $summaryPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-devmode-summary.json'
    Test-Path -LiteralPath $summaryPath | Should -BeTrue

    $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    $summary.TotalRecords | Should -Be 3

    $summary.ConfigErrors       | Should -Not -BeNullOrEmpty
    $summary.ConfigErrors.Total | Should -Be 2

    $reasons = $summary.ConfigErrors.Reasons
    $reasons | Should -Not -BeNullOrEmpty

    ($reasons | Where-Object { $_.Reason -eq 'invalid-json' }).Count | Should -Be 1
    ($reasons | Where-Object { $_.Reason -eq 'file-not-found' }).Count | Should -Be 1
  }

  It 'summarizes LvaddonRoot paths and workspace membership' {
    $root = Join-Path $TestDrive 'workspace-roots'
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    $devModeDir = Join-Path $root 'tools/x-cli-develop/temp_telemetry/labview-devmode'
    New-Item -ItemType Directory -Path $devModeDir -Force | Out-Null

    $insideRoot  = Join-Path $root 'vendor\labview-icon-editor'
    $outsideRoot = Join-Path $TestDrive 'other-lvaddon-root'

    $invPath = Join-Path $devModeDir 'invocations.jsonl'
    @(
      # run with a single root entirely inside the workspace
      [pscustomobject]@{
        RunId       = 'run-same-root'
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'OpInside1'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = $insideRoot
        Script      = 'Tooling/PrepareIESource.vi'
        ExitCode    = 0
      },
      [pscustomobject]@{
        RunId       = 'run-same-root'
        Kind        = 'labview-devmode'
        Mode        = 'disable'
        Operation   = 'OpInside2'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = $insideRoot
        Script      = 'Tooling/RestoreIESource.vi'
        ExitCode    = 0
      },
      # run with mixed roots (inside and outside workspace)
      [pscustomobject]@{
        RunId       = 'run-mixed-root'
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'OpMixed1'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = $insideRoot
        Script      = 'Tooling/PrepareIESource.vi'
        ExitCode    = 0
      },
      [pscustomobject]@{
        RunId       = 'run-mixed-root'
        Kind        = 'labview-devmode'
        Mode        = 'disable'
        Operation   = 'OpMixed2'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = $outsideRoot
        Script      = 'Tooling/RestoreIESource.vi'
        ExitCode    = 0
      }
    ) | ForEach-Object {
      $_ | ConvertTo-Json -Depth 4 -Compress
    } | Set-Content -LiteralPath $invPath -Encoding utf8

    $env:WORKSPACE_ROOT = $root

    $summaryScript = Join-Path $PSScriptRoot 'Summarize-LabviewDevmodeLogs.ps1'
    pwsh -NoLogo -NoProfile -File $summaryScript | Out-Null

    $summaryPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-devmode-summary.json'
    Test-Path -LiteralPath $summaryPath | Should -BeTrue

    $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    $summary.TotalRecords | Should -Be 4

    $summary.LvaddonRoots | Should -Not -BeNullOrEmpty
    $summary.LvaddonRoots.Count | Should -Be 2

    $inside = $summary.LvaddonRoots | Where-Object { $_.LvaddonRoot -eq $insideRoot }
    $outside = $summary.LvaddonRoots | Where-Object { $_.LvaddonRoot -eq $outsideRoot }

    $inside | Should -Not -BeNullOrEmpty
    $inside[0].InWorkspace | Should -BeTrue
    $inside[0].Count       | Should -Be 3

    $outside | Should -Not -BeNullOrEmpty
    $outside[0].InWorkspace | Should -BeFalse
    $outside[0].Count       | Should -Be 1

    $mixedRun = $summary.ByRunId | Where-Object { $_.RunId -eq 'run-mixed-root' }
    $mixedRun | Should -Not -BeNullOrEmpty
    $mixedRun[0].LvaddonRoots | Should -Contain $insideRoot
    $mixedRun[0].LvaddonRoots | Should -Contain $outsideRoot
  }

  It 'groups enable and disable stages under the same RunId' {
    $root = Join-Path $TestDrive 'workspace-runid-enable-disable'
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    $devModeDir = Join-Path $root 'tools/x-cli-develop/temp_telemetry/labview-devmode'
    New-Item -ItemType Directory -Path $devModeDir -Force | Out-Null

    $invPath = Join-Path $devModeDir 'invocations.jsonl'
    [string]$runId = 'run-enable-disable'
    @(
      [pscustomobject]@{
        RunId       = $runId
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'enable-addtoken-2025-64'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'AddTokenToLabVIEW.ps1'
        ExitCode    = 0
      },
      [pscustomobject]@{
        RunId       = $runId
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'enable-prepare-2025-64'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'Prepare_LabVIEW_source.ps1'
        ExitCode    = 0
      },
      [pscustomobject]@{
        RunId       = $runId
        Kind        = 'labview-devmode'
        Mode        = 'disable'
        Operation   = 'disable-close-2025-64'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'Close_LabVIEW.ps1'
        ExitCode    = 0
      }
    ) | ForEach-Object {
      $_ | ConvertTo-Json -Depth 4 -Compress
    } | Set-Content -LiteralPath $invPath -Encoding utf8

    $env:WORKSPACE_ROOT = $root

    $summaryScript = Join-Path $PSScriptRoot 'Summarize-LabviewDevmodeLogs.ps1'
    pwsh -NoLogo -NoProfile -File $summaryScript | Out-Null

    $summaryPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-devmode-summary.json'
    Test-Path -LiteralPath $summaryPath | Should -BeTrue

    $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    $run = $summary.ByRunId | Where-Object { $_.RunId -eq $runId }
    $run | Should -Not -BeNullOrEmpty

    $run[0].Modes      | Should -Contain 'enable'
    $run[0].Modes      | Should -Contain 'disable'
    $run[0].Operations | Should -Contain 'enable-addtoken-2025-64'
    $run[0].Operations | Should -Contain 'enable-prepare-2025-64'
    $run[0].Operations | Should -Contain 'disable-close-2025-64'
  }

  It 'handles large Args arrays and long fields in snippet' {
    $root = Join-Path $TestDrive 'workspace-large-args'
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    $devModeDir = Join-Path $root 'tools/x-cli-develop/temp_telemetry/labview-devmode'
    New-Item -ItemType Directory -Path $devModeDir -Force | Out-Null

    $invPath = Join-Path $devModeDir 'invocations.jsonl'

    $largeArgs = 1..200 | ForEach-Object { "arg-$($_)-" + ('x' * 100) }
    $longScript = 'Tooling/PrepareIESource.vi - ' + ('y' * 500)

    [pscustomobject]@{
      Kind        = 'labview-devmode'
      Mode        = 'enable'
      Operation   = 'OpLarge'
      LvVersion   = '2025'
      Bitness     = '64'
      LvaddonRoot = 'C:\fake\lvaddon-root'
      Script      = $longScript
      Args        = $largeArgs
    } | ConvertTo-Json -Depth 4 -Compress | Set-Content -LiteralPath $invPath -Encoding utf8

    $env:WORKSPACE_ROOT = $root

    $summaryScript = Join-Path $PSScriptRoot 'Summarize-LabviewDevmodeLogs.ps1'
    pwsh -NoLogo -NoProfile -File $summaryScript | Out-Null

    $summaryPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-devmode-summary.json'
    Test-Path -LiteralPath $summaryPath | Should -BeTrue

    $snippetScript = Join-Path $PSScriptRoot 'New-LvAddonLearningSnippet.ps1'
    pwsh -NoLogo -NoProfile -File $snippetScript -MaxRecords 5 | Out-Null

    $snippetPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-learning-snippet.json'
    Test-Path -LiteralPath $snippetPath | Should -BeTrue

    $snippet = Get-Content -LiteralPath $snippetPath -Raw | ConvertFrom-Json
    $snippet.SampleRecords.Count | Should -Be 1

    $rec = $snippet.SampleRecords[0]
    $rec.Operation | Should -Be 'OpLarge'
    $rec.Args.Count | Should -Be 200
    $rec.Args[0]   | Should -Match '^arg-1-'
    $rec.Args[-1]  | Should -Match '^arg-200-'
  }

  It 'scales to hundreds of records with MaxRecords tail' {
    $root = Join-Path $TestDrive 'workspace-volume'
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    $devModeDir = Join-Path $root 'tools/x-cli-develop/temp_telemetry/labview-devmode'
    New-Item -ItemType Directory -Path $devModeDir -Force | Out-Null

    $invPath = Join-Path $devModeDir 'invocations.jsonl'
    $count = 300
    $lines = 1..$count | ForEach-Object {
      [pscustomobject]@{
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = ("Op{0}" -f $_)
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'Tooling/PrepareIESource.vi'
        Args        = @()
      } | ConvertTo-Json -Depth 4 -Compress
    }
    $lines | Set-Content -LiteralPath $invPath -Encoding utf8

    $env:WORKSPACE_ROOT = $root

    $summaryScript = Join-Path $PSScriptRoot 'Summarize-LabviewDevmodeLogs.ps1'
    pwsh -NoLogo -NoProfile -File $summaryScript | Out-Null

    $summaryPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-devmode-summary.json'
    Test-Path -LiteralPath $summaryPath | Should -BeTrue

    $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    $summary.TotalRecords | Should -Be $count

    $snippetScript = Join-Path $PSScriptRoot 'New-LvAddonLearningSnippet.ps1'
    $maxRecords = 50
    pwsh -NoLogo -NoProfile -File $snippetScript -MaxRecords $maxRecords | Out-Null

    $snippetPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-learning-snippet.json'
    Test-Path -LiteralPath $snippetPath | Should -BeTrue

    $snippet = Get-Content -LiteralPath $snippetPath -Raw | ConvertFrom-Json
    $snippet.SampleRecords.Count | Should -Be $maxRecords

    $snippet.SampleRecords[0].Operation | Should -Be 'Op251'
    $snippet.SampleRecords[$maxRecords - 1].Operation | Should -Be 'Op300'
  }

  It 'summarizes resource failures across records' {
    $root = Join-Path $TestDrive 'workspace-resource-failures'
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    $devModeDir = Join-Path $root 'tools/x-cli-develop/temp_telemetry/labview-devmode'
    New-Item -ItemType Directory -Path $devModeDir -Force | Out-Null

    $invPath = Join-Path $devModeDir 'invocations.jsonl'
    @(
      [pscustomobject]@{
        Kind              = 'labview-devmode'
        Mode              = 'enable'
        Operation         = 'OpDiskFull'
        LvVersion         = '2025'
        Bitness           = '64'
        LvaddonRoot       = 'C:\fake\lvaddon-root'
        Script            = 'Tooling/PrepareIESource.vi'
        ExitCode          = 1
        ResourceError     = $true
        ResourceErrorDetail = 'disk-full'
      },
      [pscustomobject]@{
        Kind              = 'labview-devmode'
        Mode              = 'enable'
        Operation         = 'OpTempMissing'
        LvVersion         = '2025'
        Bitness           = '64'
        LvaddonRoot       = 'C:\fake\lvaddon-root'
        Script            = 'Tooling/PrepareIESource.vi'
        ExitCode          = 1
        ResourceError     = $true
        ResourceErrorDetail = 'temp-missing'
      },
      [pscustomobject]@{
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'OpNormal'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'Tooling/PrepareIESource.vi'
        ExitCode    = 0
      }
    ) | ForEach-Object {
      $_ | ConvertTo-Json -Depth 4 -Compress
    } | Set-Content -LiteralPath $invPath -Encoding utf8

    $env:WORKSPACE_ROOT = $root

    $summaryScript = Join-Path $PSScriptRoot 'Summarize-LabviewDevmodeLogs.ps1'
    pwsh -NoLogo -NoProfile -File $summaryScript | Out-Null

    $summaryPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-devmode-summary.json'
    Test-Path -LiteralPath $summaryPath | Should -BeTrue

    $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    $summary.TotalRecords | Should -Be 3

    $summary.ResourceFailures       | Should -Not -BeNullOrEmpty
    $summary.ResourceFailures.Total | Should -Be 2

    $rfReasons = $summary.ResourceFailures.Reasons
    $rfReasons | Should -Not -BeNullOrEmpty

    ($rfReasons | Where-Object { $_.Reason -eq 'disk-full' }).Count    | Should -Be 1
    ($rfReasons | Where-Object { $_.Reason -eq 'temp-missing' }).Count | Should -Be 1
  }

  It 'summarizes toolchain failures across records' {
    $root = Join-Path $TestDrive 'workspace-toolchain-failures'
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    $devModeDir = Join-Path $root 'tools/x-cli-develop/temp_telemetry/labview-devmode'
    New-Item -ItemType Directory -Path $devModeDir -Force | Out-Null

    $invPath = Join-Path $devModeDir 'invocations.jsonl'
    @(
      [pscustomobject]@{
        Kind              = 'labview-devmode'
        Mode              = 'enable'
        Operation         = 'OpGcliMissing'
        LvVersion         = '2025'
        Bitness           = '64'
        LvaddonRoot       = 'C:\fake\lvaddon-root'
        Script            = 'Tooling/PrepareIESource.vi'
        ExitCode          = 1
        ToolchainError     = $true
        ToolchainErrorDetail = 'gcli-missing'
      },
      [pscustomobject]@{
        Kind              = 'labview-devmode'
        Mode              = 'enable'
        Operation         = 'OpLvUnsupported'
        LvVersion         = '2020'
        Bitness           = '64'
        LvaddonRoot       = 'C:\fake\lvaddon-root'
        Script            = 'Tooling/PrepareIESource.vi'
        ExitCode          = 1
        ToolchainError     = $true
        ToolchainErrorDetail = 'lv-version-unsupported'
      },
      [pscustomobject]@{
        Kind        = 'labview-devmode'
        Mode        = 'enable'
        Operation   = 'OpNormalToolchain'
        LvVersion   = '2025'
        Bitness     = '64'
        LvaddonRoot = 'C:\fake\lvaddon-root'
        Script      = 'Tooling/PrepareIESource.vi'
        ExitCode    = 0
      }
    ) | ForEach-Object {
      $_ | ConvertTo-Json -Depth 4 -Compress
    } | Set-Content -LiteralPath $invPath -Encoding utf8

    $env:WORKSPACE_ROOT = $root

    $summaryScript = Join-Path $PSScriptRoot 'Summarize-LabviewDevmodeLogs.ps1'
    pwsh -NoLogo -NoProfile -File $summaryScript | Out-Null

    $summaryPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-devmode-summary.json'
    Test-Path -LiteralPath $summaryPath | Should -BeTrue

    $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    $summary.TotalRecords | Should -Be 3

    $summary.ToolchainFailures       | Should -Not -BeNullOrEmpty
    $summary.ToolchainFailures.Total | Should -Be 2

    $tcReasons = $summary.ToolchainFailures.Reasons
    $tcReasons | Should -Not -BeNullOrEmpty

    ($tcReasons | Where-Object { $_.Reason -eq 'gcli-missing' }).Count          | Should -Be 1
    ($tcReasons | Where-Object { $_.Reason -eq 'lv-version-unsupported' }).Count | Should -Be 1
  }
}
