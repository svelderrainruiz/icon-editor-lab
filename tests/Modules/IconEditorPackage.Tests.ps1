$root = $env:WORKSPACE_ROOT
if (-not $root) { $root = '/mnt/data/repo_local' }
if (-not (Test-Path -LiteralPath $root -PathType Container)) {
    $scriptDir = Split-Path -Parent $PSCommandPath
    $probe = $scriptDir
    while ($probe -and (Split-Path -Leaf $probe) -ne 'tests') {
        $next = Split-Path -Parent $probe
        if (-not $next -or $next -eq $probe) { break }
        $probe = $next
    }
    if ($probe -and (Split-Path -Leaf $probe) -eq 'tests') {
        $root = Split-Path -Parent $probe
    }
    else {
        $root = $scriptDir
    }
}
$repoRoot = (Resolve-Path -LiteralPath $root).Path
$tmp = Join-Path $repoRoot '.tmp-tests'
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$modulePath = Join-Path $repoRoot 'src/tools/icon-editor/IconEditorPackage.psm1'

if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
    Describe 'IconEditorPackage module' {
        It 'skips when IconEditorPackage.psm1 is absent' -Skip {
            # Module not present.
        }
    }
    return
}

Import-Module $modulePath -Force

if (-not (Get-Command -Name Find-LabVIEWVersionExePath -ErrorAction SilentlyContinue)) {
    function global:Find-LabVIEWVersionExePath { throw 'Find-LabVIEWVersionExePath should be mocked during tests.' }
}
if (-not (Get-Command -Name Get-LabVIEWIniPath -ErrorAction SilentlyContinue)) {
    function global:Get-LabVIEWIniPath { throw 'Get-LabVIEWIniPath should be mocked during tests.' }
}
if (-not (Get-Command -Name Get-LabVIEWIniValue -ErrorAction SilentlyContinue)) {
    function global:Get-LabVIEWIniValue { throw 'Get-LabVIEWIniValue should be mocked during tests.' }
}

Describe 'IconEditorPackage module' {
    Context 'Get-IconEditorPackageName' {
        It 'returns a trimmed package name from the VIPB file' {
            $vipbPath = Join-Path $TestDrive 'Icon.vipb'
@'
<VI_Package_Builder_Settings>
  <Library_General_Settings>
    <Package_File_Name>IconPkg </Package_File_Name>
  </Library_General_Settings>
</VI_Package_Builder_Settings>
'@ | Set-Content -LiteralPath $vipbPath -Encoding UTF8

            $result = InModuleScope IconEditorPackage {
                Get-IconEditorPackageName -VipbPath $args[0]
            } -ArgumentList $vipbPath

            $result | Should -Be 'IconPkg'
        }

        It 'throws when the package name node is missing' {
            $vipbPath = Join-Path $TestDrive 'Missing.vipb'
            '<VI_Package_Builder_Settings />' | Set-Content -LiteralPath $vipbPath -Encoding UTF8

            { InModuleScope IconEditorPackage { Get-IconEditorPackageName -VipbPath $args[0] } -ArgumentList $vipbPath } | Should -Throw
        }
    }

    Context 'Get-IconEditorPackagePath' {
        BeforeEach {
            $script:workspaceRoot = Join-Path $TestDrive ([guid]::NewGuid())
            New-Item -ItemType Directory -Path $script:workspaceRoot | Out-Null
            $script:vipbPath = Join-Path $script:workspaceRoot 'IconEditor.vipb'
@'
<VI_Package_Builder_Settings>
  <Library_General_Settings>
    <Package_File_Name>IconPkg</Package_File_Name>
  </Library_General_Settings>
</VI_Package_Builder_Settings>
'@ | Set-Content -LiteralPath $script:vipbPath -Encoding UTF8
        }

        It 'generates the expected package path under the workspace root' {
            $actual = InModuleScope IconEditorPackage {
                Get-IconEditorPackagePath -VipbPath $args[0] -Major 1 -Minor 2 -Patch 3 -Build 4 -WorkspaceRoot $args[1]
            } -ArgumentList $script:vipbPath, $script:workspaceRoot

            $expectedDir = Join-Path $script:workspaceRoot '.github/builds/VI Package'
            $expectedPath = Join-Path $expectedDir 'IconPkg-1.2.3.4.vip'
            $actual | Should -Be ([System.IO.Path]::GetFullPath($expectedPath))
        }

        It 'honors an absolute output directory even when workspace root is omitted' {
            $absoluteOutput = Join-Path $TestDrive 'artifacts'
            New-Item -ItemType Directory -Path $absoluteOutput | Out-Null
            $fallbackLocation = Join-Path $TestDrive 'fallback'
            New-Item -ItemType Directory -Path $fallbackLocation | Out-Null

            $script:FallbackLocation = $fallbackLocation
            Mock -ModuleName IconEditorPackage Get-Location { [pscustomobject]@{ Path = $script:FallbackLocation } }

            $actual = InModuleScope IconEditorPackage {
                Get-IconEditorPackagePath -VipbPath $args[0] -Major 9 -Minor 9 -Patch 9 -Build 9 -OutputDirectory $args[1]
            } -ArgumentList $script:vipbPath, $absoluteOutput

            $expectedPath = Join-Path $absoluteOutput 'IconPkg-9.9.9.9.vip'
            $actual | Should -Be ([System.IO.Path]::GetFullPath($expectedPath))
        }

        It 'uses the current working directory when workspace root is not provided' {
            $script:fallbackRepoRoot = Join-Path $TestDrive 'repo-root'
            New-Item -ItemType Directory -Path $script:fallbackRepoRoot -Force | Out-Null
            Mock -ModuleName IconEditorPackage Get-Location { [pscustomobject]@{ Path = $script:fallbackRepoRoot } }

            $actual = InModuleScope IconEditorPackage {
                Get-IconEditorPackagePath -VipbPath $args[0] -Major 1 -Minor 0 -Patch 0 -Build 0
            } -ArgumentList $script:vipbPath

            $expected = Join-Path $script:fallbackRepoRoot '.github/builds/VI Package/IconPkg-1.0.0.0.vip'
            $actual | Should -Be ([System.IO.Path]::GetFullPath($expected))
        }
    }

    Context 'Confirm-IconEditorPackageArtifact' {
        It 'returns metadata for the package file' {
            $packagePath = Join-Path $TestDrive 'Icon.vip'
            'artifact-bytes' | Set-Content -LiteralPath $packagePath -Encoding UTF8

            $result = InModuleScope IconEditorPackage {
                Confirm-IconEditorPackageArtifact -PackagePath $args[0]
            } -ArgumentList $packagePath

            $result.PackagePath | Should -Be ((Resolve-Path -LiteralPath $packagePath).Path)
            $result.Sha256 | Should -Match '^[A-F0-9]{64}$'
            $result.SizeBytes | Should -BeGreaterThan 0
        }

        It 'throws when the package path is empty' {
            try {
                InModuleScope IconEditorPackage {
                    Confirm-IconEditorPackageArtifact -PackagePath ''
                }
                throw 'Expected Confirm-IconEditorPackageArtifact to reject empty paths.'
            } catch {
                $_.Exception.Message | Should -Match "Cannot bind argument to parameter 'PackagePath'"
            }
        }

        It 'throws when the package path does not resolve to a file' {
            $missingPath = Join-Path $TestDrive 'missing.vip'
            try {
                InModuleScope IconEditorPackage {
                    Confirm-IconEditorPackageArtifact -PackagePath $args[0]
                } -ArgumentList $missingPath
                throw 'Expected Confirm-IconEditorPackageArtifact to reject missing files.'
            } catch {
                $_.Exception.Message | Should -Match ([System.Text.RegularExpressions.Regex]::Escape($missingPath))
            }
        }

        It 'throws when the resolved path is a directory instead of a file' {
            $dirPath = Join-Path $TestDrive 'artifact-dir'
            New-Item -ItemType Directory -Path $dirPath | Out-Null
            { InModuleScope IconEditorPackage { Confirm-IconEditorPackageArtifact -PackagePath $args[0] } -ArgumentList $dirPath } | Should -Throw
        }
    }

    Context 'Get-IconEditorViServerSnapshot' {
        BeforeEach {
            Mock -ModuleName IconEditorPackage Invoke-IconEditorVendorToolsImport { $true }
            Mock -ModuleName IconEditorPackage Find-LabVIEWVersionExePath { 'C:\Program Files\LabVIEW 2025\LabVIEW.exe' }
            Mock -ModuleName IconEditorPackage Get-LabVIEWIniPath { 'C:\Program Files\LabVIEW 2025\LabVIEW.ini' }
            Mock -ModuleName IconEditorPackage Get-LabVIEWIniValue {
                param([string]$LabVIEWIniPath, [string]$Key)
                switch ($Key) {
                    'server.tcp.enabled' { return 'TRUE ' }
                    'server.tcp.port' { return '3363' }
                    default { return $null }
                }
            }
        }

        It 'reports vendor-tools-missing when helper modules cannot be imported' {
            Mock -ModuleName IconEditorPackage Invoke-IconEditorVendorToolsImport { $false }

            $snapshot = InModuleScope IconEditorPackage {
                Get-IconEditorViServerSnapshot -Version 2025 -Bitness 64
            }

            $snapshot.Status | Should -Be 'vendor-tools-missing'
            $snapshot.Message | Should -Match 'VendorTools'
        }

        It 'surfaces errors thrown while resolving the LabVIEW executable' {
            Mock -ModuleName IconEditorPackage Find-LabVIEWVersionExePath { throw 'resolution failed' }

            $snapshot = InModuleScope IconEditorPackage {
                Get-IconEditorViServerSnapshot -Version 2025 -Bitness 32
            }

            $snapshot.Status | Should -Be 'error'
            $snapshot.Message | Should -Match 'resolution failed'
        }

        It 'marks snapshots missing when LabVIEW cannot be located' {
            Mock -ModuleName IconEditorPackage Find-LabVIEWVersionExePath { $null }

            $snapshot = InModuleScope IconEditorPackage {
                Get-IconEditorViServerSnapshot -Version 2025 -Bitness 32
            }

            $snapshot.Status | Should -Be 'missing'
            $snapshot.Message | Should -Match 'not found'
        }

        It 'captures ini resolution errors with the exe path in the payload' {
            Mock -ModuleName IconEditorPackage Get-LabVIEWIniPath { throw 'ini lookup failed' }

            $snapshot = InModuleScope IconEditorPackage {
                Get-IconEditorViServerSnapshot -Version 2025 -Bitness 64
            }

            $snapshot.Status | Should -Be 'error'
            $snapshot.ExePath | Should -Match 'LabVIEW.exe'
            $snapshot.Message | Should -Match 'ini'
        }

        It 'reports missing-ini when the INI cannot be found' {
            Mock -ModuleName IconEditorPackage Get-LabVIEWIniPath { $null }

            $snapshot = InModuleScope IconEditorPackage {
                Get-IconEditorViServerSnapshot -Version 2025 -Bitness 64
            }

            $snapshot.Status | Should -Be 'missing-ini'
            $snapshot.ExePath | Should -Match 'LabVIEW.exe'
        }

        It 'parses server enablement and port values when present' {
            $snapshot = InModuleScope IconEditorPackage {
                Get-IconEditorViServerSnapshot -Version 2025 -Bitness 64
            }

            $snapshot.Status | Should -Be 'ok'
            $snapshot.ServerEnabled | Should -BeTrue
            $snapshot.Enabled | Should -Be 'TRUE '
            $snapshot.Port | Should -Be 3363
        }
    }

    Context 'Get-IconEditorViServerSnapshots' {
        It 'returns a snapshot per requested bitness' {
            Mock -ModuleName IconEditorPackage Get-IconEditorViServerSnapshot {
                param([int]$Version, [int]$Bitness, [string]$WorkspaceRoot)
                return [pscustomobject]@{
                    Version = $Version
                    Bitness = $Bitness
                    Status  = 'ok'
                }
            }

            $snapshots = InModuleScope IconEditorPackage {
                Get-IconEditorViServerSnapshots -Version 2024 -Bitness @(64, 32)
            }

            $snapshots.Count | Should -Be 2
            ($snapshots.Bitness | Sort-Object) | Should -Be @(32, 64)
        }

        It 'records error entries when a snapshot call throws' {
            Mock -ModuleName IconEditorPackage Get-IconEditorViServerSnapshot {
                param([int]$Version, [int]$Bitness, [string]$WorkspaceRoot)
                if ($Bitness -eq 64) {
                    throw "bitness-$Bitness boom"
                }
                return [pscustomobject]@{
                    Version = $Version
                    Bitness = $Bitness
                    Status  = 'ok'
                }
            }

            $snapshots = InModuleScope IconEditorPackage {
                Get-IconEditorViServerSnapshots -Version 2024 -Bitness @(64, 32)
            }

            $errorEntry = $snapshots | Where-Object { $_.Status -eq 'error' }
            $errorEntry.Bitness | Should -Be 64
            $errorEntry.Message | Should -Match 'bitness-64'
        }
    }
}


