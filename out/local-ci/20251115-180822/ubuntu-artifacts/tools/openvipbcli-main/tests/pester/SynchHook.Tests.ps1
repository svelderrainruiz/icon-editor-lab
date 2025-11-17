Describe "synch-hook.ps1 helper functions" {
    BeforeAll {
        # Set env to skip hooks, then load functions
        $env:SEED_INSIGHT_TEST = '1'
        $Hook = Join-Path $PSScriptRoot '..\..\.githooks\synch-hook.ps1'
        . $Hook
    }

    It "Get-MinVersionFromFile returns '0.0.0' without blocks" {
        $tmp = New-TemporaryFile
        '{"foo":"bar"}' | Set-Content $tmp
        Get-MinVersionFromFile $tmp | Should -Be '0.0.0'
    }
}
