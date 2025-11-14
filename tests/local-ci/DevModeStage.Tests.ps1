#Requires -Version 7.0

$helpersPath = Join-Path $PSScriptRoot '..' '..' 'local-ci' 'windows' 'modules' 'DevModeStageHelpers.psm1'
if (-not (Test-Path -LiteralPath $helpersPath -PathType Leaf)) {
    throw "DevMode helpers not found at $helpersPath"
}
Import-Module $helpersPath -Force

Describe 'Resolve-LocalCiDevModeAction' -Tag 'LocalCI','DevMode' {
  It 'defaults to enable when no action is provided' {
    $result = Resolve-LocalCiDevModeAction
    $result.Action | Should -Be 'enable'
    $result.Message | Should -BeNullOrEmpty
  }

  It 'respects Skip regardless of cleanup settings' {
    $result = Resolve-LocalCiDevModeAction -RequestedAction 'Skip' -DisableAtEnd:$true
    $result.Action | Should -Be 'skip'
    $result.Message | Should -BeNullOrEmpty
  }

  It 'forces Enable when cleanup stage is responsible for disabling' {
    $result = Resolve-LocalCiDevModeAction -RequestedAction 'Disable' -DisableAtEnd:$true
    $result.Action | Should -Be 'enable'
    $result.Message | Should -Match 'Stage 55'
  }

  It 'allows Disable when cleanup is not deferred' {
    $result = Resolve-LocalCiDevModeAction -RequestedAction 'Disable' -DisableAtEnd:$false
    $result.Action | Should -Be 'disable'
    $result.Message | Should -BeNullOrEmpty
  }
}

Describe 'Resolve-DevModeForceClosePreference' -Tag 'LocalCI','DevMode' {
  BeforeEach {
    Remove-Item Env:LOCALCI_DEV_MODE_FORCE_CLOSE -ErrorAction SilentlyContinue
  }

  It 'follows configured value when no override is present' {
    Resolve-DevModeForceClosePreference -ConfiguredAllowForceClose:$false | Should -BeFalse
    Resolve-DevModeForceClosePreference -ConfiguredAllowForceClose:$true | Should -BeTrue
  }

  It 'honours LOCALCI_DEV_MODE_FORCE_CLOSE=1 regardless of config' {
    $env:LOCALCI_DEV_MODE_FORCE_CLOSE = '1'
    Resolve-DevModeForceClosePreference -ConfiguredAllowForceClose:$false | Should -BeTrue
  }

  It 'turns force close off when override is falsey' {
    $env:LOCALCI_DEV_MODE_FORCE_CLOSE = 'off'
    Resolve-DevModeForceClosePreference -ConfiguredAllowForceClose:$true | Should -BeFalse
  }
}

AfterAll {
  Remove-Module DevModeStageHelpers -Force -ErrorAction SilentlyContinue
  Remove-Item Env:LOCALCI_DEV_MODE_FORCE_CLOSE -ErrorAction SilentlyContinue
}
