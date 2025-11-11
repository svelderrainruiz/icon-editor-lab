# Pester v5 tests for tools module
# import the first Tools module found in repo tools/
$toolsDirs = Get-ChildItem -Path (Join-Path $PSScriptRoot '..') -Directory -Recurse | Where-Object { $_.Name -eq 'tools' }
$modulePath = $null
foreach ($d in $toolsDirs) {
    $candidate = Join-Path $d.FullName 'Tools.psd1'
    if (Test-Path $candidate) { $modulePath = $candidate; break }
}
if (-not $modulePath) { throw "Tools.psd1 not found." }
Import-Module $modulePath -Force

Describe 'Tools module exported functions' {
    $cmds = Get-Command -Module (Get-Module -Name Tools) | Where-Object { $_.CommandType -eq 'Function' }

    It 'exports at least one function' {
        $cmds.Count | Should -BeGreaterThan 0
    }

    It 'each function supports ShouldProcess (CmdletBinding) and -WhatIf parameter' -ForEach $cmds {
        $_.ScriptBlock.Attributes[0].SupportsShouldProcess | Should -Be $true
        $_.Parameters.Keys | Should -Contain 'WhatIf'
    }

    It 'each function has a non-empty .SYNOPSIS' -ForEach $cmds {
        $help = Get-Help $_.Name -ErrorAction SilentlyContinue
        $help | Should -Not -BeNullOrEmpty
        $help.Synopsis | Should -Not -BeNullOrEmpty
        $help.Synopsis.Trim().ToLower() | Should -Not -Match 'todo|brief description'
    }

    It 'each function accepts -WhatIf without throwing' -ForEach $cmds {
        { & $_.Name -WhatIf } | Should -Not -Throw
    }
}
