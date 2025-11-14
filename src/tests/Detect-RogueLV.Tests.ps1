#Requires -Version 7.0

Describe 'Detect-RogueLV.ps1' -Tag 'DevMode','Rogue','DetectRogue' {
  BeforeAll {
    $script:detectScript = Join-Path $PSScriptRoot '..' 'tools' 'Detect-RogueLV.ps1'
    if (-not (Test-Path -LiteralPath $script:detectScript -PathType Leaf)) {
      throw "Detect-RogueLV.ps1 not found at $script:detectScript"
    }

    function script:Invoke-DetectRogueScript {
      param(
        [string[]]$ExtraArgs
      )
      $args = @('-NoLogo','-NoProfile','-File', $script:detectScript) + $ExtraArgs
      & pwsh @args | Out-Null
      return $LASTEXITCODE
    }
  }

  It 'emits a rogue payload when OutputPath is provided' {
    $testRoot = Join-Path ((Resolve-Path $TestDrive).ProviderPath) ([Guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
    $resultsDir = Join-Path $testRoot 'rogue-results'
    $outputPath = Join-Path $testRoot 'rogue-out' 'rogue-lv.json'
    $exitCode = Invoke-DetectRogueScript -ExtraArgs @(
      '-ResultsDir', $resultsDir,
      '-OutputPath', $outputPath,
      '-LookBackSeconds', '1',
      '-RetryCount', '1',
      '-RetryDelaySeconds', '0',
      '-Quiet'
    )
    $exitCode | Should -Be 0
    Test-Path -LiteralPath $outputPath -PathType Leaf | Should -BeTrue
    $payload = Get-Content -LiteralPath $outputPath -Raw | ConvertFrom-Json
    $payload.schema | Should -Be 'rogue-lv-detection/v1'
    $payload.noticeDir | Should -Be (Join-Path $resultsDir '_lvcompare_notice')
    $payload.rogue.labview | Should -BeNullOrEmpty
  }

}
