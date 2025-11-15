$root = $env:WORKSPACE_ROOT
if (-not $root) { $root = '/mnt/data/repo_local' }
$repoRoot = (Resolve-Path -LiteralPath $root).Path
$tmp = Join-Path $repoRoot '.tmp-tests'
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$modulePath = Join-Path $repoRoot 'src/tools/CompareVI.Tools/CompareVI.Tools.psm1'

if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
    Describe 'CompareVI.Tools module' {
        It 'skips when CompareVI.Tools.psm1 is absent' -Skip {
            # Module not present.
        }
    }
    return
}

Import-Module $modulePath -Force

Describe 'CompareVI.Tools module' {
    Context 'Get-CompareVIScriptPath' {
        It 'resolves the path for an existing script' {
            $result = InModuleScope CompareVI.Tools {
                Get-CompareVIScriptPath -Name 'Compare-VIHistory.ps1'
            }
            $result | Should -Match 'Compare-VIHistory.ps1$'
            Test-Path -LiteralPath $result | Should -BeTrue
        }

        It 'throws when the script does not exist' {
            { InModuleScope CompareVI.Tools { Get-CompareVIScriptPath -Name 'missing-script.ps1' } } | Should -Throw
        }
    }

    Context 'Invoke-CompareVIHistory' {
        It 'invokes the helper script and clears COMPAREVI_SCRIPTS_ROOT' {
            $historyStub = Join-Path $TestDrive 'Compare-VIHistory.ps1'
            $recordPath = Join-Path $TestDrive 'history.json'
@"
param(
    [Parameter(Mandatory)][string]
    `$TargetPath,
    [string]`$StartRef
)
@{
    TargetPath = `$TargetPath
    StartRef   = `$StartRef
    ScriptsRoot = `$env:COMPAREVI_SCRIPTS_ROOT
} | ConvertTo-Json | Set-Content -LiteralPath '$recordPath'
"@ | Set-Content -LiteralPath $historyStub -Encoding UTF8

            $script:HistoryStubPath = $historyStub
            Mock -ModuleName CompareVI.Tools Get-CompareVIScriptPath { $script:HistoryStubPath }

            InModuleScope CompareVI.Tools {
                Invoke-CompareVIHistory -TargetPath 'vi/lib/Icon.vi' -StartRef 'HEAD~1'
            }

            $payload = Get-Content -LiteralPath $recordPath -Raw | ConvertFrom-Json
            $payload.TargetPath | Should -Be 'vi/lib/Icon.vi'
            $payload.StartRef | Should -Be 'HEAD~1'
            $payload.ScriptsRoot | Should -Not -BeNullOrEmpty
            (Test-Path Env:COMPAREVI_SCRIPTS_ROOT) | Should -BeFalse
        }

        It 'clears the scripts root environment variable even when helper script fails' {
            $historyStub = Join-Path $TestDrive 'Compare-VIHistory.ps1'
            "throw 'history failure'" | Set-Content -LiteralPath $historyStub -Encoding UTF8

            $script:HistoryStubPath = $historyStub
            Mock -ModuleName CompareVI.Tools Get-CompareVIScriptPath { $script:HistoryStubPath }

            try {
                InModuleScope CompareVI.Tools {
                    Invoke-CompareVIHistory -TargetPath 'vi/lib/Icon.vi'
                }
                throw 'Expected Invoke-CompareVIHistory to bubble up script errors.'
            } catch {
                $_.Exception.Message | Should -Match 'history failure'
            }
            (Test-Path Env:COMPAREVI_SCRIPTS_ROOT) | Should -BeFalse
        }
    }

    Context 'Invoke-CompareRefsToTemp' {
        It 'passes arguments through to the comparison script' {
            $stubPath = Join-Path $TestDrive 'Compare-RefsToTemp.ps1'
            $recordPath = Join-Path $TestDrive 'refs.json'
@"
param(
    [string]`$Path,
    [string]`$RefA,
    [string]`$RefB
)
@{
    Path = `$Path
    RefA = `$RefA
    RefB = `$RefB
} | ConvertTo-Json | Set-Content -LiteralPath '$recordPath'
"@ | Set-Content -LiteralPath $stubPath -Encoding UTF8

            $script:RefsStubPath = $stubPath
            Mock -ModuleName CompareVI.Tools Get-CompareVIScriptPath { $script:RefsStubPath }

            InModuleScope CompareVI.Tools {
                Invoke-CompareRefsToTemp -Path 'foo.vi' -RefA 'A' -RefB 'B'
            }

            $payload = Get-Content -LiteralPath $recordPath -Raw | ConvertFrom-Json
            $payload.Path | Should -Be 'foo.vi'
            $payload.RefA | Should -Be 'A'
            $payload.RefB | Should -Be 'B'
        }

        It 'supports invoking comparisons by VI name rather than explicit path' {
            $stubPath = Join-Path $TestDrive 'Compare-RefsToTemp.ps1'
            $recordPath = Join-Path $TestDrive 'refs-by-name.json'
@"
param(
    [string]`$ViName,
    [string]`$RefA,
    [string]`$RefB
)
@{
    ViName = `$ViName
    RefA   = `$RefA
    RefB   = `$RefB
} | ConvertTo-Json | Set-Content -LiteralPath '$recordPath'
"@ | Set-Content -LiteralPath $stubPath -Encoding UTF8

            $script:RefsByNameStub = $stubPath
            Mock -ModuleName CompareVI.Tools Get-CompareVIScriptPath { $script:RefsByNameStub }

            InModuleScope CompareVI.Tools {
                Invoke-CompareRefsToTemp -ViName 'Icon' -RefA 'origin/main' -RefB 'feature/change'
            }

            $payload = Get-Content -LiteralPath $recordPath -Raw | ConvertFrom-Json
            $payload.ViName | Should -Be 'Icon'
            $payload.RefA | Should -Be 'origin/main'
            $payload.RefB | Should -Be 'feature/change'
        }
    }

    Context 'Test-ValidLabel' {
        It 'accepts labels composed of safe characters' {
            InModuleScope CompareVI.Tools {
                Test-ValidLabel -Label 'Valid_Label-1.2'
            }
        }

        It 'throws when the label contains invalid characters' {
            { InModuleScope CompareVI.Tools { Test-ValidLabel -Label 'bad label!' } } | Should -Throw
        }
    }

    Context 'Invoke-WithTimeout' {
        It 'returns the output of the script block before the timeout' {
            $result = InModuleScope CompareVI.Tools {
                Invoke-WithTimeout -ScriptBlock { 'done' } -TimeoutSec 5
            }
            $result | Should -Be 'done'
        }

        It 'throws when the script block exceeds the timeout' {
            try {
                InModuleScope CompareVI.Tools {
                    Invoke-WithTimeout -ScriptBlock { Start-Sleep -Seconds 1 } -TimeoutSec 0
                }
                throw 'Expected Invoke-WithTimeout to time out.'
            } catch {
                $_.Exception.Message | Should -Match 'Operation timed out'
            }
        }
    }
}
