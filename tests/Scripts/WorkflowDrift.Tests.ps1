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
. (Join-Path $root 'tests/_helpers/Import-ScriptFunctions.ps1')
$scriptPath = Join-Path $repoRoot 'src/tools/Check-WorkflowDrift.ps1'
$scriptExists = Test-Path -LiteralPath $scriptPath -PathType Leaf
if ($scriptExists) {
    Import-ScriptFunctions -Path $scriptPath -FunctionNames @('Resolve-PythonExe','Process-Staging','Test-ValidLabel') | Out-Null
}

Describe 'Check-WorkflowDrift.ps1' {
    if (-not $scriptExists) {
        It 'skips when Check-WorkflowDrift.ps1 is absent' -Skip {
            # File not present in this repo snapshot.
        }
        return
    }

    Context 'Resolve-PythonExe' {
        It 'returns the first available python executable' {
            $fakePython = Join-Path $TestDrive 'python.exe'
            New-Item -ItemType File -Path $fakePython | Out-Null
            Mock -CommandName Get-Command -MockWith {
                param([string]$Name, [object]$ErrorAction)
                [pscustomobject]@{ Source = $fakePython }
            }
            Resolve-PythonExe | Should -Be $fakePython
            Assert-MockCalled -CommandName Get-Command -Times 1
        }

        It 'falls back to py.exe when python.exe is unavailable' {
            $pyPath = Join-Path $TestDrive 'py.exe'
            New-Item -ItemType File -Path $pyPath | Out-Null
            Mock -CommandName Get-Command -MockWith {
                param([string]$Name, [object]$ErrorAction)
                if ($Name -eq 'python') { return $null }
                return [pscustomobject]@{ Source = $pyPath }
            }

            Resolve-PythonExe | Should -Be $pyPath
            Assert-MockCalled -CommandName Get-Command -Times 2
        }

        It 'returns null when no candidates are available' {
            Mock -CommandName Get-Command -MockWith {
                param([string]$Name, [object]$ErrorAction)
                $null
            }
            Resolve-PythonExe | Should -BeNullOrEmpty
        }
    }

    Context 'Process-Staging' {
        BeforeEach {
            $script:Stage = $true
            $script:CommitMessage = 'update workflows'
            $script:gitDiffResponse = @('workflows/a.yml','workflows/b.yml')
            $script:gitAddCount = 0
            $script:gitCommitCount = 0
            function script:git {
                param(
                    [Parameter(ValueFromRemainingArguments=$true)]
                    [string[]]$Arguments
                )
                switch ($Arguments[0]) {
                    'add' {
                        $script:gitAddCount++
                        return
                    }
                    'diff' {
                        if ($Arguments[1] -eq '--cached' -and $Arguments[2] -eq '--name-only') {
                            return $script:gitDiffResponse
                        }
                        return ''
                    }
                    'commit' {
                        $script:gitCommitCount++
                        return ''
                    }
                    default { return '' }
                }
            }
        }

        AfterEach {
            Remove-Item -Path Function:\git -ErrorAction SilentlyContinue
        }

        It 'adds and commits changes when only workflow files are staged' {
            $changed = @('workflows/a.yml','workflows/b.yml')
            Process-Staging -ChangedFiles $changed
            $script:gitAddCount | Should -Be 1
            $script:gitCommitCount | Should -Be 1
        }

        It 'avoids committing when unrelated files are staged' {
            $changed = @('workflows/a.yml')
            $script:gitDiffResponse = @('workflows/a.yml','README.md')
            Mock -CommandName Write-Host -ParameterFilter { $Object -like '::warning::*' } -MockWith {
                param([string]$Object)
                $script:lastWarning = $Object
            }

            { Process-Staging -ChangedFiles $changed } | Should -Not -Throw
            $script:lastWarning | Should -Match 'Additional files already staged'
            Assert-MockCalled -CommandName Write-Host -Times 1 -ParameterFilter { $Object -like '::warning::*' }
            $script:gitCommitCount | Should -Be 0
        }

        It 'emits a notice and skips work when no files are staged' {
            Mock -CommandName Write-Host -ParameterFilter { $Object -like '::notice::No workflow drift*' } -MockWith {
                param([string]$Object)
                $script:lastNotice = $Object
            }

            Process-Staging -ChangedFiles @()

            $script:lastNotice | Should -Match 'No workflow drift'
            Assert-MockCalled -CommandName Write-Host -Times 1 -ParameterFilter { $Object -like '::notice::No workflow drift*' }
            $script:gitAddCount | Should -Be 0
        }

        It 'skips staging entirely when Stage is disabled and no commit message is provided' {
            $script:Stage = $false
            $script:CommitMessage = $null

            { Process-Staging -ChangedFiles @('workflows/a.yml') } | Should -Not -Throw
            $script:gitAddCount | Should -Be 0
        }
    }
}


