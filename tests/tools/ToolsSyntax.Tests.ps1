#requires -Version 7.0

Describe 'Tools folder script syntax' -Tag 'tools','Windows','CI' {
    It 'has a tools directory' {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
        $root = Join-Path $repoRoot 'tools'
        Test-Path -LiteralPath $root | Should -BeTrue -Because "tools/ must exist to run sanity checks."
    }

    It 'contains at least one PowerShell file' {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
        $toolsRoot = Join-Path $repoRoot 'tools'
        if (Test-Path -LiteralPath $toolsRoot) {
            $scripts = @(Get-ChildItem -LiteralPath $toolsRoot -Include *.ps1,*.psm1 -Recurse -File -ErrorAction SilentlyContinue)
        } else {
            $scripts = @()
        }
        $scripts.Count | Should -BeGreaterThan 0 -Because "tool sanity tests require at least one script under tools/."
    }

    $cases = & {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
        $toolsRoot = Join-Path $repoRoot 'tools'
        if (-not (Test-Path -LiteralPath $toolsRoot)) { return @() }
        Get-ChildItem -LiteralPath $toolsRoot -Include *.ps1,*.psm1 -Recurse -File -ErrorAction SilentlyContinue |
            ForEach-Object {
                @{
                    Relative = $_.FullName.Substring($repoRoot.Length + 1)
                    FullName = $_.FullName
                }
            }
    }

    It 'parses <Relative>' -TestCases $cases {
        param($Relative, $FullName)
        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($FullName, [ref]$tokens, [ref]$errors) | Out-Null
        $errors | Should -BeNullOrEmpty -Because "syntax errors prevent automation from dot-sourcing $Relative."
    }
}
