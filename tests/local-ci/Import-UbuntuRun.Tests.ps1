#Requires -Version 7.0

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $here '..' '..')).ProviderPath
$modulePath = Join-Path $repoRoot 'local-ci/windows/scripts/Import-UbuntuRun.psm1'
Import-Module -Name $modulePath -Force

Describe 'Import-UbuntuRun.ps1' {
    BeforeEach {
        Remove-Item Env:LOCALCI_IMPORT_UBUNTU_RUN -ErrorAction SilentlyContinue
    }

    It 'returns null when no manifest hint is provided' {
        $runRoot = Join-Path $TestDrive 'run-root'
        New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
        $result = Invoke-UbuntuRunImport -RepoRoot $repoRoot -RunRoot $runRoot -SkipGitCheck
        $result | Should -BeNullOrEmpty
    }

    It 'imports manifest and extracts artifacts' {
        $repo = Join-Path $TestDrive 'repo'
        New-Item -ItemType Directory -Path $repo -Force | Out-Null
        $zipRel = 'out/local-ci-ubuntu/20250101-000000/local-ci-artifacts.zip'
        $zipFull = Join-Path $repo $zipRel
        New-Item -ItemType Directory -Path (Split-Path -Parent $zipFull) -Force | Out-Null

        $payloadDir = Join-Path $TestDrive 'payload'
        New-Item -ItemType Directory -Path $payloadDir -Force | Out-Null
        'hello from ubuntu' | Set-Content -LiteralPath (Join-Path $payloadDir 'hello.txt')
        Compress-Archive -Path (Join-Path $payloadDir '*') -DestinationPath $zipFull -Force

        $manifestData = @{
            runner    = 'ubuntu'
            timestamp = '20250101-000000'
            git       = @{ commit = 'abc123'; branch = 'develop' }
            paths     = @{
                repo_root         = $repo
                run_root          = 'out/local-ci-ubuntu/20250101-000000'
                sign_root         = 'out'
                artifact_zip_rel  = $zipRel
                artifact_zip_abs  = $zipFull
                coverage_xml_rel  = 'out/coverage/coverage.xml'
            }
            coverage  = @{
                percent     = 88
                min_percent = 75
            }
            stages    = @(
                @{ id = '10'; name = '10-prep'; status = 'succeeded'; log = 'out/local-ci-ubuntu/10-prep.log'; duration_seconds = 1 }
            )
        }
        $manifestDir = Join-Path $TestDrive 'manifest'
        New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null
        $manifestPath = Join-Path $manifestDir 'ubuntu-run.json'
        $manifestData | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

        $runRoot = Join-Path $TestDrive 'windows-run'
        New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
        $result = Invoke-UbuntuRunImport -ManifestPath $manifestDir -RepoRoot $repo -RunRoot $runRoot -SkipGitCheck

        $result | Should -Not -BeNullOrEmpty
        Test-Path (Join-Path $runRoot 'ubuntu-artifacts/hello.txt') | Should -BeTrue
        Test-Path (Join-Path $runRoot 'ubuntu-import.json') | Should -BeTrue
        $result.ZipPath | Should -Be $zipFull
        $result.Manifest.timestamp | Should -Be '20250101-000000'
    }

    It 'fails when artifact zip cannot be located' {
        $repo = Join-Path $TestDrive 'repo-missing'
        New-Item -ItemType Directory -Path $repo -Force | Out-Null
        $manifestData = @{
            runner    = 'ubuntu'
            timestamp = '20250101-000000'
            git       = @{ commit = 'abc123'; branch = 'develop' }
            paths     = @{
                repo_root        = $repo
                run_root         = 'out/local-ci-ubuntu/20250101-000000'
                sign_root        = 'out'
                artifact_zip_rel = 'out/local-ci-ubuntu/20250101-000000/local-ci-artifacts.zip'
            }
            coverage  = $null
            stages    = @()
        }
        $manifestPath = Join-Path $TestDrive 'bad-manifest.json'
        $manifestData | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
        $runRoot = Join-Path $TestDrive 'windows-run-missing'
        New-Item -ItemType Directory -Path $runRoot -Force | Out-Null

        { Invoke-UbuntuRunImport -ManifestPath $manifestPath -RepoRoot $repo -RunRoot $runRoot -SkipGitCheck } | Should -Throw 'Artifact zip from manifest not found*'
    }
}
