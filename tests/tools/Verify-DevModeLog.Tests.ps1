#Requires -Version 7.0
#Requires -Modules Pester

param()

Describe 'Verify-DevModeLog script' -Tag 'DevMode','LvAddon' {
  It 'prints lv-addon root path from telemetry without error' {
    $root = Join-Path $TestDrive 'workspace'
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    $agentDir = Join-Path $root 'tests/results/_agent/icon-editor/dev-mode-run'
    New-Item -ItemType Directory -Path $agentDir -Force | Out-Null
    $latest = Join-Path $agentDir 'latest-run.json'

    $telemetry = [pscustomobject]@{
      lvAddonRootPath          = 'C:\fake\lvaddon-root'
      lvAddonRootSource        = 'parameter'
      lvAddonRootMode          = 'Strict'
      lvAddonRootOrigin        = 'https://github.com/example/labview-icon-editor.git'
      lvAddonRootHost          = 'github.com'
      lvAddonRootIsLVAddonLab  = $true
    }

    $telemetry | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $latest -Encoding utf8

    $scriptPath = Join-Path $PSScriptRoot '..' '..' 'tests/tools/Verify-DevModeLog.ps1'
    $env:WORKSPACE_ROOT = $root
    $output = pwsh -NoLogo -NoProfile -File $scriptPath 2>&1

    $checkLine = $output | Where-Object { $_ -like '[devscript-check]*LvAddonRoot*' } | Select-Object -First 1
    $checkLine | Should -Not -BeNullOrEmpty
    $checkLine | Should -Match 'LvAddonRoot="C:\\fake\\lvaddon-root"'
  }
}

