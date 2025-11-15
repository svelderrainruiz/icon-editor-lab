$root = $env:WORKSPACE_ROOT
if (-not $root) { $root = '/mnt/data/repo_local' }
if (-not (Test-Path -LiteralPath $root -PathType Container)) {
    $root = (Resolve-Path -LiteralPath '.').Path
}
$repoRoot = (Resolve-Path -LiteralPath $root).Path
$tmp = Join-Path $repoRoot '.tmp-tests'
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
. (Join-Path $root 'tests/_helpers/Import-ScriptFunctions.ps1')
$scriptPath = Join-Path $repoRoot 'src/tools/Check-DocsLinks.ps1'
$scriptExists = Test-Path -LiteralPath $scriptPath -PathType Leaf
if ($scriptExists) {
    Import-ScriptFunctions -Path $scriptPath -FunctionNames @('Match-Any','Write-Info','Test-ValidLabel','Invoke-WithTimeout') | Out-Null
}

Describe 'Check-DocsLinks.ps1' {
    if (-not $scriptExists) {
        It 'skips when Check-DocsLinks.ps1 is absent' -Skip {
            # File not present in this repo snapshot.
        }
        return
    }
    Context 'Test-ValidLabel' {
        It 'accepts simple labels with safe characters' {
            { Test-ValidLabel -Label 'DocsLabel_123' } | Should -Not -Throw
        }

        It 'allows dots and hyphens in varying positions' {
            { Test-ValidLabel -Label 'Alpha.BETA-1' } | Should -Not -Throw
        }

        It 'rejects values with reserved characters' {
            try {
                Test-ValidLabel -Label '#bad-label'
                throw 'Expected Test-ValidLabel to reject invalid characters.'
            } catch {
                $_.Exception.Message | Should -Match 'Invalid label'
            }
        }

        It 'rejects labels that exceed the maximum length' {
            $longLabel = 'a' * 70
            try {
                Test-ValidLabel -Label $longLabel
                throw 'Expected Test-ValidLabel to enforce the length limit.'
            } catch {
                $_.Exception.Message | Should -Match 'Invalid label'
            }
        }
    }

    Context 'Match-Any helper' {
        It 'detects matches when patterns align' {
            Match-Any -value 'docs/guides/readme.md' -patterns @('*/guides/*') | Should -BeTrue
        }

        It 'does not match when patterns do not apply' {
            Match-Any -value 'docs/guides/readme.md' -patterns @('*/bin/*') | Should -BeFalse
        }

        It 'matches when later patterns include recursive wildcards' {
            Match-Any -value 'src/docs/guide.md' -patterns @('*/bin/*', '**/docs/**') | Should -BeTrue
        }
    }

    Context 'Invoke-WithTimeout' {
        It 'invokes Start-Job and Receive-Job when the work finishes before the timeout' {
            $fakeJobId = 42
            Mock -CommandName Start-Job -MockWith {
                param([scriptblock]$ScriptBlock)
                $script:lastScript = $ScriptBlock
                return $fakeJobId
            }
            Mock -CommandName Wait-Job -MockWith {
                param([int[]]$Id,[int]$Timeout)
                $Id | Should -Contain $fakeJobId
                $Timeout | Should -Be 5
                return $true
            }
            Mock -CommandName Receive-Job -MockWith {
                param([int[]]$Id,[System.Management.Automation.ActionPreference]$ErrorAction)
                $Id | Should -Contain $fakeJobId
                $ErrorAction | Should -Be ([System.Management.Automation.ActionPreference]::Stop)
                return 'finished'
            }
            Mock -CommandName Stop-Job -MockWith {
                param([int[]]$Id,[switch]$Force)
            }

            $result = Invoke-WithTimeout -ScriptBlock { 'payload' } -TimeoutSec 5
            $result | Should -Be 'finished'

            Assert-MockCalled -CommandName Start-Job -Times 1 -ParameterFilter { $null -ne $ScriptBlock }
            Assert-MockCalled -CommandName Wait-Job -Times 1 -ParameterFilter { $Timeout -eq 5 -and $Id -contains $fakeJobId }
            Assert-MockCalled -CommandName Receive-Job -Times 1 -ParameterFilter { $Id -contains $fakeJobId }
            Assert-MockCalled -CommandName Stop-Job -Times 0
        }

        It 'stops the job and surfaces a timeout error when Wait-Job expires' {
            $fakeJobId = 7
            Mock -CommandName Start-Job -MockWith {
                param([scriptblock]$ScriptBlock)
                return $fakeJobId
            }
            Mock -CommandName Wait-Job -MockWith {
                param([int[]]$Id,[int]$Timeout)
                return $false
            }
            Mock -CommandName Stop-Job -MockWith {
                param([int[]]$Id,[switch]$Force)
                $Id | Should -Contain $fakeJobId
                $Force | Should -BeTrue
            }
            Mock -CommandName Receive-Job -MockWith {
                param([int[]]$Id,[System.Management.Automation.ActionPreference]$ErrorAction)
                throw 'Receive-Job should not run when timeouts occur.'
            }

            try {
                Invoke-WithTimeout -ScriptBlock { 'slow-path' } -TimeoutSec 1
                throw 'Expected Invoke-WithTimeout to time out.'
            } catch {
                $_.Exception.Message | Should -Match 'timed out'
            }
            Assert-MockCalled -CommandName Receive-Job -Times 0
        }
    }
}


