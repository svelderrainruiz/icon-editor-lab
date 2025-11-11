[CmdletBinding()]
param()
#Requires -Version 7.0

Describe 'RunnerProfile utility helpers' -Tag 'Unit','Tools','RunnerProfile' {
    BeforeAll {
        $here = $PSScriptRoot
        if (-not $here -and $PSCommandPath) {
            $here = Split-Path -Parent $PSCommandPath
        }
        if (-not $here -and $MyInvocation.MyCommand.Path) {
            $here = Split-Path -Parent $MyInvocation.MyCommand.Path
        }
        if (-not $here) {
            throw 'Unable to determine test location.'
        }
        $script:RepoRoot = (Resolve-Path (Join-Path $here '..\..\..')).Path
        $script:modulePath = (Resolve-Path (Join-Path $script:RepoRoot 'src/tools/RunnerProfile.psm1')).Path
        if (Get-Module -Name RunnerProfile -ErrorAction SilentlyContinue) {
            Remove-Module RunnerProfile -Force -ErrorAction SilentlyContinue
        }
        Import-Module -Name $script:modulePath -Force -ErrorAction Stop
    }

    AfterAll {
        if (Get-Module -Name RunnerProfile -ErrorAction SilentlyContinue) {
            Remove-Module RunnerProfile -Force -ErrorAction SilentlyContinue
        }
    }

    BeforeEach {
        $script:envBackup = @{}
        foreach ($name in @(
            'RUNNER_LABELS','RUNNER_NAME','RUNNER_OS','RUNNER_ENVIRONMENT','RUNNER_ARCH','RUNNER_TRACKING_ID',
            'ImageOS','ImageVersion','GITHUB_REPOSITORY','GITHUB_RUN_ID','GITHUB_JOB','GITHUB_RUN_ATTEMPT',
            'GH_TOKEN','GITHUB_TOKEN'
        )) {
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

    Context 'Get-RunnerLabels caching and API fallback' {
        It 'hydrates from API when env is empty and caches the result' {
            $env:RUNNER_LABELS = ''
            InModuleScope RunnerProfile {
                Mock -ModuleName RunnerProfile -CommandName Get-RunnerLabelsFromApi -MockWith { @('self-hosted','windows-2025') }
                $first = Get-RunnerLabels -ForceRefresh
                $second = Get-RunnerLabels
                $first | Should -Contain 'self-hosted'
                $second | Should -Be $first
                Assert-MockCalled -ModuleName RunnerProfile -CommandName Get-RunnerLabelsFromApi -Times 1 -Exactly
            }
        }
    }

    Context 'Get-RunnerLabelsFromApi' {
        It 'selects jobs matching runner name and attempt when API returns data' {
            $env:GITHUB_REPOSITORY = 'contoso/icon-editor'
            $env:GITHUB_RUN_ID = '42'
            $env:RUNNER_NAME = 'runner-a'
            $env:GITHUB_JOB = 'coverage'
            $env:GITHUB_RUN_ATTEMPT = '3'
            InModuleScope RunnerProfile {
                Mock -ModuleName RunnerProfile -CommandName Invoke-RunnerJobsApi -MockWith {
                    @(
                        [pscustomobject]@{ runner_name='runner-a'; labels=@('self-hosted','windows'); run_attempt=3; name='coverage'; status='completed' },
                        [pscustomobject]@{ runner_name='runner-b'; labels=@('linux','x64'); run_attempt=1; name='coverage'; status='completed' }
                    )
                }
                $labels = Get-RunnerLabelsFromApi
                $labels | Should -Contain 'self-hosted'
                $labels | Should -Contain 'windows'
                $labels | Should -Not -Contain 'linux'
            }
        }

        It 'returns empty when repository metadata is missing' {
            InModuleScope RunnerProfile {
                Get-RunnerLabelsFromApi | Should -BeNullOrEmpty
            }
        }

        It 'falls back to job name and latest non-queued run when runner name is absent' {
            $env:GITHUB_REPOSITORY = 'contoso/icon-editor'
            $env:GITHUB_RUN_ID = '77'
            $env:GITHUB_JOB = 'e2e'
            $env:GITHUB_RUN_ATTEMPT = ''
            InModuleScope RunnerProfile {
                Mock -ModuleName RunnerProfile -CommandName Invoke-RunnerJobsApi -MockWith {
                    @(
                        [pscustomobject]@{ runner_name=$null; name='build'; status='completed'; started_at=[datetime]'2025-11-11'; labels=@('build') },
                        [pscustomobject]@{ runner_name=$null; name='e2e'; status='in_progress'; started_at=[datetime]'2025-11-12'; labels=@('e2e','windows') },
                        [pscustomobject]@{ runner_name=$null; name='e2e'; status='completed'; started_at=[datetime]'2025-11-10'; labels=@('old') }
                    )
                }
                $labels = Get-RunnerLabelsFromApi
                $labels | Should -Contain 'e2e'
                $labels | Should -Contain 'windows'
                $labels | Should -Not -Contain 'old'
            }
        }

        It 'returns empty when candidate job has no labels array' {
            $env:GITHUB_REPOSITORY = 'contoso/icon-editor'
            $env:GITHUB_RUN_ID = '88'
            InModuleScope RunnerProfile {
                Mock -ModuleName RunnerProfile -CommandName Invoke-RunnerJobsApi -MockWith {
                    @([pscustomobject]@{ runner_name='abc'; labels=$null; status='completed'; name='build' })
                }
                Get-RunnerLabelsFromApi | Should -BeNullOrEmpty
            }
        }

        It 'uses run attempt metadata when multiple candidates match' {
            $env:GITHUB_REPOSITORY = 'contoso/icon-editor'
            $env:GITHUB_RUN_ID = '99'
            $env:RUNNER_NAME = 'runner-a'
            $env:GITHUB_RUN_ATTEMPT = '2'
            InModuleScope RunnerProfile {
                Mock -ModuleName RunnerProfile -CommandName Invoke-RunnerJobsApi -MockWith {
                    @(
                        [pscustomobject]@{ runner_name='runner-a'; labels=@('v1'); run_attempt=1; status='completed'; name='build' },
                        [pscustomobject]@{ runner_name='runner-a'; labels=@('v2'); run_attempt=2; status='completed'; name='build' }
                    )
                }
                $labels = Get-RunnerLabelsFromApi
                $labels | Should -Contain 'v2'
                $labels | Should -Not -Contain 'v1'
            }
        }
    }

    Context 'Invoke-RunnerJobsApi' {
        It 'returns jobs from REST API when gh CLI is unavailable' {
            $env:GH_TOKEN = 'gho_mock'
            InModuleScope RunnerProfile {
                Mock -ModuleName RunnerProfile -CommandName Get-Command -MockWith { throw [System.Management.Automation.CommandNotFoundException]::new() }
                Mock -ModuleName RunnerProfile -CommandName Invoke-RestMethod -MockWith {
                    [pscustomobject]@{
                        jobs = @(
                            [pscustomobject]@{ runner_name='runner-a'; labels=@('ubuntu'); status='completed' }
                        )
                    }
                }
                $jobs = @(Invoke-RunnerJobsApi -Repository 'contoso/icon-editor' -RunId '999')
                ($jobs | Measure-Object).Count | Should -Be 1
                $jobs[0].labels | Should -Contain 'ubuntu'
            }
        }

        It 'returns empty when no tokens are present' {
            InModuleScope RunnerProfile {
                Mock -ModuleName RunnerProfile -CommandName Get-Command -MockWith { throw [System.Management.Automation.CommandNotFoundException]::new() }
                Invoke-RunnerJobsApi -Repository 'contoso/icon-editor' -RunId '999' | Should -BeNullOrEmpty
            }
        }

        It 'prefers gh CLI output when command is available' {
            $env:GITHUB_REPOSITORY = 'contoso/icon-editor'
            $env:GITHUB_RUN_ID = '555'
            Remove-Item Env:GH_TOKEN -ErrorAction SilentlyContinue
            Remove-Item Env:GITHUB_TOKEN -ErrorAction SilentlyContinue
            InModuleScope RunnerProfile {
                Mock -ModuleName RunnerProfile -CommandName Invoke-RestMethod -MockWith { throw 'REST path should not execute' }
                Mock -ModuleName RunnerProfile -CommandName Get-Command -MockWith {
                    [pscustomobject]@{
                        Source = {
                            param([Parameter(ValueFromRemainingArguments=$true)][object[]]$Args)
                            Set-Variable -Name LASTEXITCODE -Scope Global -Value 0
                            '{"jobs":[{"runner_name":"gh-cli","labels":["macos","arm64"],"status":"completed"}]}'
                        }
                    }
                }
                $jobs = Invoke-RunnerJobsApi -Repository 'contoso/icon-editor' -RunId '555'
                $jobs | Should -Not -BeNullOrEmpty
                $jobs[0].runner_name | Should -Be 'gh-cli'
                $jobs[0].labels | Should -Contain 'macos'
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

        It 'reuses cached profile unless ForceRefresh is specified' {
            $env:RUNNER_LABELS = 'alpha,beta'
            $env:RUNNER_NAME = 'runner-1'
            $env:RUNNER_OS = 'Windows'
            InModuleScope RunnerProfile {
                $first = Get-RunnerProfile -ForceRefresh
                $env:RUNNER_LABELS = 'beta,gamma'
                $cached = Get-RunnerProfile
                $cached.labels | Should -Contain 'alpha'
                $cached.name | Should -Be 'runner-1'
                $fresh = Get-RunnerProfile -ForceRefresh
                $fresh.labels | Should -Contain 'gamma'
                $fresh.name | Should -Be 'runner-1'
            }
        }

    }
}

