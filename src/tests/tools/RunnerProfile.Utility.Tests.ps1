[CmdletBinding()]
param()
#Requires -Version 7.0

Describe 'RunnerProfile utility helpers' -Tag 'Unit','Tools','RunnerProfile' {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
        $script:modulePath = (Resolve-Path (Join-Path $script:RepoRoot 'src\tools\RunnerProfile.psm1')).Path
        if (Get-Module -Name RunnerProfile -ErrorAction SilentlyContinue) {
            Remove-Module RunnerProfile -Force -ErrorAction SilentlyContinue
        }
        $module = New-Module -Name RunnerProfile -ScriptBlock {
            param($path)
            . $path
        } -ArgumentList $script:modulePath
        Import-Module $module -Force
    }

    AfterAll {
        if (Get-Module -Name RunnerProfile -ErrorAction SilentlyContinue) {
            Remove-Module RunnerProfile -Force -ErrorAction SilentlyContinue
        }
    }

    BeforeEach {
        $script:envBackup = @{}
        foreach ($name in @('RUNNER_LABELS','RUNNER_NAME','RUNNER_OS','RUNNER_ENVIRONMENT','RUNNER_ARCH','RUNNER_TRACKING_ID','ImageOS','ImageVersion')) {
            $script:envBackup[$name] = [System.Environment]::GetEnvironmentVariable($name, 'Process')
        }
        InModuleScope RunnerProfile {
            $script:RunnerProfileCache = $null
            $script:RunnerLabelsCache = $null
        }
    }

    AfterEach {
        foreach ($entry in $script:envBackup.GetEnumerator()) {
            [System.Environment]::SetEnvironmentVariable($entry.Key, $entry.Value, 'Process')
        }
    }

    Context 'Get-EnvironmentValue' {
        It 'returns trimmed strings and null for missing values' {
            $env:RUNNER_NAME = '  build-runner '
            InModuleScope RunnerProfile {
                Get-EnvironmentValue -Name 'RUNNER_NAME' | Should -Be 'build-runner'
                Get-EnvironmentValue -Name 'DOES_NOT_EXIST' | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Parse-Labels' {
        It 'splits on commas/whitespace and de-duplicates' {
            InModuleScope RunnerProfile {
                $labels = Parse-Labels -Raw 'linux-x64, windows ,linux-x64  self-hosted'
                $labels | Should -Contain 'linux-x64'
                $labels | Should -Contain 'windows'
                $labels | Should -Contain 'self-hosted'
                $labels.Count | Should -Be 3
            }
        }
    }

    Context 'Get-RunnerLabels' {
        It 'prefers RUNNER_LABELS environment variable' {
            $env:RUNNER_LABELS = 'alpha, beta beta'
            InModuleScope RunnerProfile {
                $labels = Get-RunnerLabels -ForceRefresh
                $labels.Count | Should -Be 2
                $labels | Should -Contain 'alpha'
                $labels | Should -Contain 'beta'
            }
        }
    }

    Context 'Get-RunnerProfile' {
        It 'combines env fields and cached labels' {
            $env:RUNNER_LABELS = 'linux,windows'
            $env:RUNNER_NAME = 'ci-runner'
            $env:RUNNER_OS = 'Windows'
            $env:RUNNER_ARCH = 'X64'
            $env:ImageOS = 'windows-2025'
            $env:ImageVersion = '2025.11.02'

            InModuleScope RunnerProfile {
                $profile = Get-RunnerProfile -ForceRefresh
                $profile.name | Should -Be 'ci-runner'
                $profile.os | Should -Be 'Windows'
                $profile.labels | Should -Contain 'linux'
                $profile.labels | Should -Contain 'windows'
                $profile.machine | Should -Not -BeNullOrEmpty
            }
        }
    }
}
