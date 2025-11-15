#Requires -Version 7.0
#Requires -Modules Pester

param()

Describe 'Handshake summarizer' -Tag 'Handshake','Summary' {
  BeforeAll {
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:summarizer = Join-Path $script:repoRoot '..' 'tests/tools/Summarize-Handshakes.ps1'
    Test-Path -LiteralPath $script:summarizer | Should -BeTrue
  }

  It 'captures handshake coverage mismatch and stage failures' {
    $workspace = Join-Path $TestDrive 'handshake-workspace'
    New-Item -ItemType Directory -Path $workspace -Force | Out-Null

    $handshakeDir = Join-Path $workspace 'handshake'
    New-Item -ItemType Directory -Path $handshakeDir -Force | Out-Null

    $pointer = [ordered]@{
      schema  = 'handshake/v1'
      sequence = 1
      status  = 'ubuntu-ready'
      ubuntu  = [ordered]@{
        stamp        = '20250101-120000'
        artifact     = 'ubuntu-local-ci-20250101-120000'
        manifest_rel = 'out/local-ci-ubuntu/20250101-120000/ubuntu-run.json'
        manifest_abs = '/fake/out/local-ci-ubuntu/20250101-120000/ubuntu-run.json'
        pointer      = 'out/local-ci-ubuntu/latest.json'
        updated_at   = '2025-01-01T12:01:00Z'
      }
      windows = [ordered]@{
        status   = 'pending'
        updated_at = $null
        run_root = $null
        stamp    = $null
        runner   = $null
        job      = '123456789'
      }
    }
    $pointer | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $handshakeDir 'pointer.json') -Encoding utf8

    $localCiRoot = Join-Path $workspace 'out/local-ci'
    $runRoot = Join-Path $localCiRoot '20250101-120500'
    New-Item -ItemType Directory -Path $runRoot -Force | Out-Null

    $runMeta = [ordered]@{
      RepoRoot  = $workspace
      SignRoot  = (Join-Path $workspace 'out')
      RunRoot   = $runRoot
      Timestamp = '20250101-120500'
      GitCommit = 'fake'
      GitBranch = 'test-branch'
      Stages    = @(
        [ordered]@{
          Id        = 10
          Label     = 'Prep'
          BitnessId = ''
          Status    = 'Failed'
          LogPath   = (Join-Path $runRoot 'stage-10-Prep.log')
          DurationMs = 1000
          Error     = '[EnvParity] Environment parity check failed'
        },
        [ordered]@{
          Id        = 37
          Label     = 'VICompare (2021-64)'
          BitnessId = '2021-64'
          Status    = 'Succeeded'
          LogPath   = (Join-Path $runRoot 'stage-37-VICompare-2021-64.log')
          DurationMs = 200
          Error     = $null
        }
      )
    }
    $runMeta | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $runRoot 'run-metadata.json') -Encoding utf8

    $import = [ordered]@{
      ManifestPath = (Join-Path $workspace 'out/local-ci-ubuntu/20250101-120000/ubuntu-run.json')
      ImportedZip  = '/fake/out/local-ci-ubuntu/20250101-120000/local-ci-artifacts.zip'
      ExtractedPath = (Join-Path $runRoot 'ubuntu-artifacts')
      GitCommit    = 'abcdef1234567890'
      GitBranch    = 'develop'
      Coverage     = [ordered]@{
        percent     = 60.0
        min_percent = 75.0
        report      = 'out/coverage/coverage.xml'
      }
      RunId        = '20250101-120000-abcdef12'
      CreatedUtc   = '2025-01-01T12:00:00Z'
      Timestamp    = '20250101-120000-abcdef12'
    }
    $import | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $runRoot 'ubuntu-import.json') -Encoding utf8

    $env:WORKSPACE_ROOT = $workspace

    $outputPath = Join-Path $workspace 'tests/results/_agent/icon-editor/handshake-summary.json'
    $outputDir = Split-Path -Parent $outputPath
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

    pwsh -NoLogo -NoProfile -File $script:summarizer -OutputPath $outputPath | Out-Null

    Test-Path -LiteralPath $outputPath | Should -BeTrue

    $summary = Get-Content -LiteralPath $outputPath -Raw | ConvertFrom-Json
    $summary.schema    | Should -Be 'icon-editor/handshake-summary@v1'
    $summary.totalRuns | Should -Be 1

    $summary.pointer.Status         | Should -Be 'ubuntu-ready'
    $summary.pointer.UbuntuStamp    | Should -Be '20250101-120000'
    $summary.pointer.WindowsStatus  | Should -Be 'pending'

    $run = $summary.runs[0]
    $run.Stamp           | Should -Be '20250101-120500'
    $run.PrepStatus      | Should -Be 'Failed'
    $run.VICompareStatus | Should -Be 'Succeeded'
    $run.CoveragePercent | Should -Be 60.0
    $run.CoverageMin     | Should -Be 75.0
    $run.CoverageBelowMin | Should -BeTrue
    $run.HasFailure      | Should -BeTrue
  }
}

