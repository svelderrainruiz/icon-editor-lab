$root = $env:WORKSPACE_ROOT
if (-not $root) { $root = '/mnt/data/repo_local' }
$repoRoot = (Resolve-Path -LiteralPath $root).Path
$tmp = Join-Path $repoRoot '.tmp-tests'
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$script:PackagingRepoRoot = $repoRoot
$script:HashArtifactsScriptPath = Join-Path $repoRoot 'tools/Hash-Artifacts.ps1'
$script:ExportBundleScriptPath = Join-Path $repoRoot 'tools/Export-SemverBundle.ps1'

Describe 'Hash-Artifacts.ps1' {
    $hashArtifactsScriptPath = $script:HashArtifactsScriptPath

    if (-not (Test-Path -LiteralPath $hashArtifactsScriptPath -PathType Leaf)) {
        It 'skips when Hash-Artifacts.ps1 is absent' -Skip {
            # Script not present.
        }
        return
    }

    BeforeAll {
        $script:ResolvedHashArtifactsPath = (Convert-Path $hashArtifactsScriptPath)
    }

    Context 'happy path' {
        It 'writes deterministic checksums for files under the root' {
            $root = Join-Path $TestDrive 'artifacts'
            $nested = Join-Path $root 'nested'
            New-Item -ItemType Directory -Path $nested -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $root 'a.txt') -Value 'alpha'
            Set-Content -LiteralPath (Join-Path $nested 'b.txt') -Value 'beta'
            $rootPath = Convert-Path $root

            Import-Module Microsoft.PowerShell.Management -ErrorAction SilentlyContinue | Out-Null
            Import-Module Microsoft.PowerShell.Utility -ErrorAction SilentlyContinue | Out-Null
            $stdOut = @()
            $stdErr = @()
            $exitCode = 0
            $originalPreference = $ErrorActionPreference
            try {
                $ErrorActionPreference = 'Stop'
                $stdOut = & $script:ResolvedHashArtifactsPath -Root $rootPath
            } catch {
                $exitCode = 1
                $stdErr = @((($_ | Out-String).Trim()))
            } finally {
                $ErrorActionPreference = $originalPreference
            }

            $result = [pscustomobject]@{
                ExitCode = $exitCode
                StdOut   = @($stdOut | ForEach-Object { $_.ToString() })
                StdErr   = @($stdErr | Where-Object { $_ })
            }
            $result.ExitCode | Should -Be 0
            ($result.StdOut -join [Environment]::NewLine) | Should -Match 'Wrote checksums'

            $checksumFile = Join-Path $root 'checksums.sha256'
            Test-Path -LiteralPath $checksumFile | Should -BeTrue
            $checksums = Get-Content -LiteralPath $checksumFile -Raw
            $checksums | Should -Match 'a\.txt'
            $checksums | Should -Match 'nested[/\\]b\.txt'
        }
    }

    Context 'error cases' {
        It 'returns a non-zero exit code when the root directory does not exist' {
            $missingRoot = Join-Path ((Get-Location).Path) ([guid]::NewGuid().ToString())
            Import-Module Microsoft.PowerShell.Management -ErrorAction SilentlyContinue | Out-Null
            Import-Module Microsoft.PowerShell.Utility -ErrorAction SilentlyContinue | Out-Null
            $stdOut = @()
            $stdErr = @()
            $exitCode = 0
            $originalPreference = $ErrorActionPreference
            try {
                $ErrorActionPreference = 'Stop'
                $stdOut = & $script:ResolvedHashArtifactsPath -Root $missingRoot
            } catch {
                $exitCode = 1
                $stdErr = @((($_ | Out-String).Trim()))
            } finally {
                $ErrorActionPreference = $originalPreference
            }

            $result = [pscustomobject]@{
                ExitCode = $exitCode
                StdOut   = @($stdOut | ForEach-Object { $_.ToString() })
                StdErr   = @($stdErr | Where-Object { $_ })
            }
            $result.ExitCode | Should -Not -Be 0
            ($result.StdErr -join [Environment]::NewLine) | Should -Match 'Cannot find path'
        }

        It 'fails when the checksums file cannot be written because it is locked' {
            $root = Join-Path $TestDrive 'locked-hash'
            New-Item -ItemType Directory -Path $root -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $root 'artifact.txt') -Value 'data'
            $checksumFile = Join-Path $root 'checksums.sha256'
            Set-Content -LiteralPath $checksumFile -Value 'locked'
            $lock = [System.IO.File]::Open($checksumFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)

            Import-Module Microsoft.PowerShell.Management -ErrorAction SilentlyContinue | Out-Null
            Import-Module Microsoft.PowerShell.Utility -ErrorAction SilentlyContinue | Out-Null
            $stdOut = @()
            $stdErr = @()
            $exitCode = 0
            $originalPreference = $ErrorActionPreference
            try {
                $ErrorActionPreference = 'Stop'
                $stdOut = & $script:ResolvedHashArtifactsPath -Root (Convert-Path $root)
            } catch {
                $exitCode = 1
                $stdErr = @((($_ | Out-String).Trim()))
            } finally {
                $ErrorActionPreference = $originalPreference
                $lock.Dispose()
            }

            $result = [pscustomobject]@{
                ExitCode = $exitCode
                StdOut   = @($stdOut | ForEach-Object { $_.ToString() })
                StdErr   = @($stdErr | Where-Object { $_ })
            }
            $result.ExitCode | Should -Not -Be 0
            ($result.StdErr -join [Environment]::NewLine) | Should -Match 'checksums\.sha256'
        }
    }
}

Describe 'Export-SemverBundle.ps1' {
    $exportBundleScriptPath = $script:ExportBundleScriptPath

    if (-not (Test-Path -LiteralPath $exportBundleScriptPath -PathType Leaf)) {
        It 'skips when Export-SemverBundle.ps1 is absent' -Skip {
            # Script not present.
        }
        return
    }

    BeforeAll {
        $script:ResolvedExportBundlePath = (Convert-Path $exportBundleScriptPath)
    }

    Context 'bundle creation' {
        It 'creates bundle metadata and optional zip' {
            $destination = Join-Path $TestDrive 'bundle-out'
            Import-Module Microsoft.PowerShell.Management -ErrorAction SilentlyContinue | Out-Null
            Import-Module Microsoft.PowerShell.Utility -ErrorAction SilentlyContinue | Out-Null
            $stdOut = @()
            $stdErr = @()
            $exitCode = 0
            $originalPreference = $ErrorActionPreference
            try {
                $ErrorActionPreference = 'Stop'
                $stdOut = & $script:ResolvedExportBundlePath -Destination $destination -Zip -IncludeWorkflow
            } catch {
                $exitCode = 1
                $stdErr = @((($_ | Out-String).Trim()))
            } finally {
                $ErrorActionPreference = $originalPreference
            }

            $result = [pscustomobject]@{
                ExitCode = $exitCode
                StdOut   = @($stdOut | ForEach-Object { $_.ToString() })
                StdErr   = @($stdErr | Where-Object { $_ })
            }
            $result.ExitCode | Should -Be 0

            Test-Path -LiteralPath $destination | Should -BeTrue
            Test-Path -LiteralPath "$destination.zip" | Should -BeTrue
            $manifestPath = Join-Path $destination 'bundle.json'
            $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
            ($manifest.files.relativePath) | Should -Contain 'docs/semver-guard-kit.md'
        }

        It 'throws when a required source file is missing' {
            $destination = Join-Path $TestDrive 'bundle-missing'
            Mock -CommandName Test-Path -MockWith {
                param(
                    [string]$Path,
                    [string]$LiteralPath,
                    [Microsoft.PowerShell.Commands.TestPathType]$PathType
                )
                $targetPath = $null
                if ($LiteralPath) {
                    $targetPath = $LiteralPath
                } elseif ($Path) {
                    $targetPath = $Path
                }
                if ($PathType -eq 'Leaf' -and $targetPath -match 'docs[\\/ ]semver-guard-kit\.md') {
                    return $false
                }
                switch ($PathType) {
                    'Leaf' {
                        return [System.IO.File]::Exists($targetPath)
                    }
                    'Container' {
                        return [System.IO.Directory]::Exists($targetPath)
                    }
                    default {
                        if (-not $targetPath) { return $false }
                        return [System.IO.File]::Exists($targetPath) -or [System.IO.Directory]::Exists($targetPath)
                    }
                }
            }

            try {
                & $script:ResolvedExportBundlePath -Destination $destination -Zip
                throw 'Expected Export-SemverBundle.ps1 to raise a missing source error.'
            } catch {
                $_.Exception.Message | Should -Match 'Source file not found'
            }
            Assert-MockCalled -CommandName Test-Path -Times 1 -ParameterFilter { $LiteralPath -match 'docs[\\/ ]semver-guard-kit\.md' -and $PathType -eq 'Leaf' }
        }
    }

    Context 'copy to target repo' {
        It 'fails when the target repo layout blocks copying bundle artifacts' {
            $destination = Join-Path $TestDrive 'bundle-invalid-target'
            $targetRepo = Join-Path $TestDrive 'target-invalid'
            New-Item -ItemType Directory -Path $targetRepo -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $targetRepo 'src') -Value 'blocked'
            Import-Module Microsoft.PowerShell.Management -ErrorAction SilentlyContinue | Out-Null
            Import-Module Microsoft.PowerShell.Utility -ErrorAction SilentlyContinue | Out-Null

            try {
                & $script:ResolvedExportBundlePath -Destination $destination -TargetRepoRoot $targetRepo | Out-Null
                throw 'Expected Export-SemverBundle.ps1 to fail when src is a file.'
            } catch {
                $_.Exception.Message | Should -Match 'src'
            }
        }

        It 'copies bundle contents into the provided target repo root' {
            $destination = Join-Path $TestDrive 'bundle-mirror'
            $targetRepo = Join-Path $TestDrive 'adopter'
            Import-Module Microsoft.PowerShell.Management -ErrorAction SilentlyContinue | Out-Null
            Import-Module Microsoft.PowerShell.Utility -ErrorAction SilentlyContinue | Out-Null
            $stdOut = @()
            $stdErr = @()
            $exitCode = 0
            $originalPreference = $ErrorActionPreference
            try {
                $ErrorActionPreference = 'Stop'
                $stdOut = & $script:ResolvedExportBundlePath -Destination $destination -TargetRepoRoot $targetRepo
            } catch {
                $exitCode = 1
                $stdErr = @((($_ | Out-String).Trim()))
            } finally {
                $ErrorActionPreference = $originalPreference
            }

            $result = [pscustomobject]@{
                ExitCode = $exitCode
                StdOut   = @($stdOut | ForEach-Object { $_.ToString() })
                StdErr   = @($stdErr | Where-Object { $_ })
            }
            $result.ExitCode | Should -Be 0

            Test-Path -LiteralPath (Join-Path $targetRepo 'src/tools/priority/validate-semver.mjs') | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $targetRepo 'docs/semver-guard-kit.md') | Should -BeTrue
        }
    }
}
