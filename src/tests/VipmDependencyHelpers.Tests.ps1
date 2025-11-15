#Requires -Version 7.0
#Requires -Modules Pester

param()

Describe 'VipmDependencyHelpers core contracts' -Tag 'Vipm','VipmDependencies','Unit' {
  BeforeAll {
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
    $script:modulePath = Join-Path $script:repoRoot 'tools/icon-editor/VipmDependencyHelpers.psm1'
    if (-not (Test-Path -LiteralPath $script:modulePath -PathType Leaf)) {
      # Fallback to src path when tools mirror is not present
      $script:modulePath = Join-Path $script:repoRoot 'src/tools/icon-editor/VipmDependencyHelpers.psm1'
    }
    Import-Module $script:modulePath -Force
  }

  Context 'Get-VipmProviderInstallParameters' {
    It 'throws when vipm-gcli extras are requested without a VIPC path' {
      InModuleScope VipmDependencyHelpers {
        { Get-VipmProviderInstallParameters -ProviderName 'vipm-gcli' -RepoRoot 'C:\repo' -LabVIEWVersion '2023' -LabVIEWBitness '64' } |
          Should -Throw 'vipm-gcli provider requires a VIPC path.'
      }
    }

    It 'returns applyVipcPath and targetVersion extras for vipm-gcli' {
      InModuleScope VipmDependencyHelpers {
        Mock Resolve-VipmApplyVipcPath { return 'C:\repo\vendor\icon-editor\Tooling\deployment\Applyvipc.vi' }
        Mock Get-VipmDisplayVersionString { param($LabVIEWVersion,$LabVIEWBitness) return "LV-$LabVIEWVersion-$LabVIEWBitness" }

        $extras = Get-VipmProviderInstallParameters `
          -ProviderName 'vipm-gcli' `
          -RepoRoot 'C:\repo' `
          -LabVIEWVersion '2023' `
          -LabVIEWBitness '64' `
          -VipcPath 'C:\deps\icon-editor.vipc'

        $extras.applyVipcPath | Should -Be 'C:\repo\vendor\icon-editor\Tooling\deployment\Applyvipc.vi'
        $extras.targetVersion | Should -Be 'LV-2023-64'
      }
    }
  }

  Context 'Test-VipmCliReady' {
    It 'throws when LabVIEW executable cannot be resolved' {
      InModuleScope VipmDependencyHelpers {
        function Import-Module { }
        function Resolve-VipmApplyVipcPath {
          param([string]$RepoRoot)
          'C:\repo\vendor\icon-editor\Tooling\deployment\Applyvipc.vi'
        }
        function Get-VipmDisplayVersionString {
          param([string]$LabVIEWVersion,[string]$LabVIEWBitness)
          "LV-$LabVIEWVersion-$LabVIEWBitness"
        }
        function Find-LabVIEWVersionExePath {
          param([int]$Version, [int]$Bitness)
          return $null
        }
        function Get-VipmInvocation {
          param([string]$Operation,[hashtable]$Params,[string]$ProviderName)
          throw 'should not be called'
        }

        { Test-VipmCliReady -LabVIEWVersion '2023' -LabVIEWBitness '64' -RepoRoot 'C:\repo' -ProviderName 'vipm-gcli' -VipcPath 'C:\deps\icon-editor.vipc' } |
          Should -Throw '*LabVIEW 2023 (64-bit) was not detected.*'
      }
    }

    It 'throws when Get-VipmInvocation indicates provider is not ready' {
      InModuleScope VipmDependencyHelpers {
        function Import-Module { }
        function Resolve-VipmApplyVipcPath {
          param([string]$RepoRoot)
          'C:\repo\vendor\icon-editor\Tooling\deployment\Applyvipc.vi'
        }
        function Get-VipmDisplayVersionString {
          param([string]$LabVIEWVersion,[string]$LabVIEWBitness)
          "LV-$LabVIEWVersion-$LabVIEWBitness"
        }
        function Find-LabVIEWVersionExePath {
          param([int]$Version, [int]$Bitness)
          'C:\Program Files\LabVIEW 2023\LabVIEW.exe'
        }
        function Get-VipmInvocation {
          param([string]$Operation,[hashtable]$Params,[string]$ProviderName)
          throw 'provider not configured'
        }

        { Test-VipmCliReady -LabVIEWVersion '2023' -LabVIEWBitness '32' -RepoRoot 'C:\repo' -ProviderName 'vipm-gcli' -VipcPath 'C:\deps\icon-editor.vipc' } |
          Should -Throw "*VIPM provider 'vipm-gcli' is not ready: provider not configured*"
      }
    }

    It 'returns provider and LabVIEW exe path on success' {
      InModuleScope VipmDependencyHelpers {
        function Import-Module { }
        function Resolve-VipmApplyVipcPath {
          param([string]$RepoRoot)
          'C:\repo\vendor\icon-editor\Tooling\deployment\Applyvipc.vi'
        }
        function Get-VipmDisplayVersionString {
          param([string]$LabVIEWVersion,[string]$LabVIEWBitness)
          "LV-$LabVIEWVersion-$LabVIEWBitness"
        }
        function Find-LabVIEWVersionExePath {
          param([int]$Version, [int]$Bitness)
          'C:\LV2025\LabVIEW.exe'
        }
        function Get-VipmInvocation {
          param([string]$Operation,[hashtable]$Params,[string]$ProviderName)
          [pscustomobject]@{
            Provider  = 'vipm-gcli'
            Binary    = 'C:\vipm.exe'
            Arguments = @()
          }
        }

        $result = Test-VipmCliReady -LabVIEWVersion '2025' -LabVIEWBitness '64' -RepoRoot 'C:\repo' -ProviderName 'vipm-gcli' -VipcPath 'C:\deps\icon-editor.vipc'
        $result | Should -Not -BeNullOrEmpty
        $result.provider   | Should -Be 'vipm-gcli'
        $result.labviewExe | Should -Be 'C:\LV2025\LabVIEW.exe'
      }
    }
  }

  Context 'Install-VipmVipc' {
    It 'throws with exit code and stderr when VIPM process fails' {
      InModuleScope VipmDependencyHelpers {
        function Resolve-VipmApplyVipcPath {
          param([string]$RepoRoot)
          'C:\repo\vendor\icon-editor\Tooling\deployment\Applyvipc.vi'
        }
        function Get-VipmDisplayVersionString {
          param([string]$LabVIEWVersion,[string]$LabVIEWBitness)
          "LV-$LabVIEWVersion-$LabVIEWBitness"
        }
        function Get-VipmInvocation {
          param([string]$Operation,[hashtable]$Params,[string]$ProviderName)
          [pscustomobject]@{
            Provider  = 'vipm-gcli'
            Binary    = 'C:\vipm.exe'
            Arguments = @('-vipc','C:\deps\icon-editor.vipc')
          }
        }
        function Invoke-VipmProcess {
          param([psobject]$Invocation,[string]$WorkingDirectory)
          [pscustomobject]@{
            ExitCode = 5
            StdOut   = ''
            StdErr   = 'vipm internal error'
          }
        }
        function Write-VipmTelemetryLog {
          param(
            [string]$LogRoot,
            [string]$Provider,
            [string]$Binary,
            [string[]]$Arguments,
            [string]$WorkingDirectory,
            [int]$ExitCode,
            [string]$StdOut,
            [string]$StdErr,
            [string]$LabVIEWVersion,
            [string]$LabVIEWBitness
          )
          'telemetry-path'
        }

        { Install-VipmVipc -VipcPath 'C:\deps\icon-editor.vipc' -LabVIEWVersion '2023' -LabVIEWBitness '64' -RepoRoot 'C:\repo' -TelemetryRoot 'C:\telemetry' -ProviderName 'vipm-gcli' } |
          Should -Throw "Process exited with code 5.*vipm internal error*"
      }
    }

    It 'writes installed-packages log only for vipm provider' {
      InModuleScope VipmDependencyHelpers {
        $script:getCalls = 0
        $script:logCalls = 0

        function Resolve-VipmApplyVipcPath {
          param([string]$RepoRoot)
          'C:\repo\vendor\icon-editor\Tooling\deployment\Applyvipc.vi'
        }
        function Get-VipmDisplayVersionString {
          param([string]$LabVIEWVersion,[string]$LabVIEWBitness)
          "LV-$LabVIEWVersion-$LabVIEWBitness"
        }

        function Get-VipmInvocation {
          param([string]$Operation,[hashtable]$Params,[string]$ProviderName)
          [pscustomobject]@{
            Provider  = 'vipm'
            Binary    = 'C:\vipm.exe'
            Arguments = @('-vipc','C:\deps\icon-editor.vipc')
          }
        }
        function Invoke-VipmProcess {
          param([psobject]$Invocation,[string]$WorkingDirectory)
          [pscustomobject]@{
            ExitCode = 0
            StdOut   = 'ok'
            StdErr   = ''
          }
        }
        function Write-VipmTelemetryLog {
          param(
            [string]$LogRoot,
            [string]$Provider,
            [string]$Binary,
            [string[]]$Arguments,
            [string]$WorkingDirectory,
            [int]$ExitCode,
            [string]$StdOut,
            [string]$StdErr,
            [string]$LabVIEWVersion,
            [string]$LabVIEWBitness
          )
          'telemetry-path'
        }
        function Get-VipmInstalledPackages {
          $script:getCalls++
          [pscustomobject]@{
            rawOutput = 'stub'
            packages  = @([pscustomobject]@{ name='pkg'; identifier='id'; version='1.0.0.0' })
          }
        }
        function Write-VipmInstalledPackagesLog {
          param(
            [string]$LogRoot,
            [string]$LabVIEWVersion,
            [string]$LabVIEWBitness,
            [object]$PackageInfo
          )
          $script:logCalls++
          'installed-path'
        }

        $result = Install-VipmVipc -VipcPath 'C:\deps\icon-editor.vipc' -LabVIEWVersion '2023' -LabVIEWBitness '32' -RepoRoot 'C:\repo' -TelemetryRoot 'C:\telemetry' -ProviderName 'vipm'

        $result.version  | Should -Be '2023'
        $result.bitness  | Should -Be '32'
        $result.packages | Should -Not -BeNullOrEmpty

        $script:getCalls | Should -Be 1
        $script:logCalls | Should -Be 1
      }
    }

  }

  Context 'Show-VipmDependencies' {
    It 'returns installed package info for classic vipm provider' {
      InModuleScope VipmDependencyHelpers {
        $script:getCalls = 0
        $script:logCalls = 0

        function Get-VipmInstalledPackages {
          $script:getCalls++
          [pscustomobject]@{
            rawOutput = 'stub'
            packages  = @([pscustomobject]@{ name='pkg'; identifier='id'; version='1.2.3.4' })
          }
        }
        function Write-VipmInstalledPackagesLog {
          param(
            [string]$LogRoot,
            [string]$LabVIEWVersion,
            [string]$LabVIEWBitness,
            [object]$PackageInfo
          )
          $script:logCalls++
          'installed-path'
        }

        $result = Show-VipmDependencies -LabVIEWVersion '2023' -LabVIEWBitness '64' -TelemetryRoot 'C:\telemetry' -ProviderName 'vipm'
        $result.version  | Should -Be '2023'
        $result.bitness  | Should -Be '64'
        $result.packages | Should -Not -BeNullOrEmpty

        $script:getCalls | Should -Be 1
        $script:logCalls | Should -Be 1
      }
    }

    It 'throws when non-vipm provider is used for display-only listing' {
      InModuleScope VipmDependencyHelpers {
        { Show-VipmDependencies -LabVIEWVersion '2023' -LabVIEWBitness '32' -TelemetryRoot 'C:\telemetry' -ProviderName 'vipm-gcli' } |
          Should -Throw "DisplayOnly mode requires the classic VIPM provider. Provider 'vipm-gcli' does not support listing installed packages."
      }
    }
  }
}
