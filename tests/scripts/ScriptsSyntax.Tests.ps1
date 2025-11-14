#requires -Version 7.0

Describe 'Scripts folder syntax' -Tag 'scripts','Windows','CI' {
    It 'has a scripts directory' {
        $repoRoot    = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
        $scriptsRoot = Join-Path $repoRoot 'scripts'
        Test-Path -LiteralPath $scriptsRoot | Should -BeTrue -Because "scripts/ must exist to run sanity checks."
    }

    It 'contains at least one PowerShell script' {
        $repoRoot    = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
        $scriptsRoot = Join-Path $repoRoot 'scripts'
        if (Test-Path -LiteralPath $scriptsRoot) {
            $scriptFiles = @(Get-ChildItem -LiteralPath $scriptsRoot -Include *.ps1,*.psm1 -Recurse -File -ErrorAction SilentlyContinue)
        } else {
            $scriptFiles = @()
        }
        $scriptFiles.Count | Should -BeGreaterThan 0 -Because "local harness scripts need at least one .ps1/.psm1 under scripts/."
    }

    $cases = & {
        $repoRoot    = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
        $scriptsRoot = Join-Path $repoRoot 'scripts'
        if (-not (Test-Path -LiteralPath $scriptsRoot)) { return @() }
        @(Get-ChildItem -LiteralPath $scriptsRoot -Include *.ps1,*.psm1 -Recurse -File -ErrorAction SilentlyContinue |
            ForEach-Object {
                @{
                    Relative = $_.FullName.Substring($repoRoot.Length + 1)
                    FullName = $_.FullName
                }
            })
    }

    It 'parses <Relative>' -TestCases $cases {
        param($Relative, $FullName)
        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($FullName, [ref]$tokens, [ref]$errors) | Out-Null
        $errors | Should -BeNullOrEmpty -Because "syntax errors prevent automation from dot-sourcing $Relative."
    }
}
