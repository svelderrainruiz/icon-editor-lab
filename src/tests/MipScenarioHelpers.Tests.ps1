
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$modulePath = Join-Path $repoRoot 'tools' 'icon-editor' 'MipScenarioHelpers.psm1'
Import-Module $modulePath -Force

Describe 'MipScenarioHelpers' -Tag 'Unit','IconEditor','MissingInProject' {
  Context 'Write-AnalyzerDevModeWarning' {
    It 'prints guidance when dev-mode flag is set' {
      $dir = Join-Path $TestDrive 'analyzer-devmode'
      New-Item -ItemType Directory -Path $dir -Force | Out-Null
      @{
        devModeLikelyDisabled = $true
      } | ConvertTo-Json -Depth 2 | Set-Content -LiteralPath (Join-Path $dir 'vi-analyzer.json') -Encoding utf8

      InModuleScope MipScenarioHelpers {
        param($dir)
        $output = Write-AnalyzerDevModeWarning -AnalyzerDir $dir -Prefix '[test]' -PassThru
        $output | Should -Match 'Enable-DevMode'
      } -ArgumentList $dir
    }

    It 'returns false when analyzer JSON missing' {
      $dir = Join-Path $TestDrive 'analyzer-empty'
      New-Item -ItemType Directory -Path $dir -Force | Out-Null
      InModuleScope MipScenarioHelpers {
        param($dir)
        Write-AnalyzerDevModeWarning -AnalyzerDir $dir | Should -BeFalse
      } -ArgumentList $dir
    }
  }
}

