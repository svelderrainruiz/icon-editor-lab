Import-Module Pester

Describe 'detect_vi_changes.py' {
    BeforeAll {
        $script:ScriptPath = Join-Path $PSScriptRoot '../../local-ci/ubuntu/scripts/detect_vi_changes.py' |
            Resolve-Path -Relative
    }

    It 'detects changed VI files between commits' {
        $repo = Join-Path $TestDrive 'vi-repo'
        git init $repo | Out-Null
        git -C $repo config user.email 'test@example.com'
        git -C $repo config user.name 'Test Runner'
        $viPath = Join-Path $repo 'Sample.vi'
        Set-Content -LiteralPath $viPath -Value 'base'
        git -C $repo add Sample.vi | Out-Null
        git -C $repo commit -m 'base' | Out-Null
        $base = (git -C $repo rev-parse HEAD).Trim()
        Set-Content -LiteralPath $viPath -Value 'changed'
        git -C $repo commit -am 'change' | Out-Null
        $head = (git -C $repo rev-parse HEAD).Trim()
        $output = Join-Path $TestDrive 'vi-list.txt'
        python3 $script:ScriptPath --repo $repo --base $base --head $head --output $output
        $results = Get-Content -LiteralPath $output
        $results | Should -Contain 'Sample.vi'
    }

    It 'emits empty list when base is missing' {
        $repo = Join-Path $TestDrive 'vi-repo2'
        git init $repo | Out-Null
        $output = Join-Path $TestDrive 'empty.txt'
        python3 $script:ScriptPath --repo $repo --output $output
        (Get-Content -LiteralPath $output | Measure-Object).Count | Should -Be 0
    }
}
