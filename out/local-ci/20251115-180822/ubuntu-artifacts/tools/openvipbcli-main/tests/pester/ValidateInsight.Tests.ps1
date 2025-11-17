Describe "validate-insight.ps1 basic behaviour" {
    BeforeAll {
        $Validator = Join-Path $PSScriptRoot '..\..\scripts\validate-insight.ps1'
    }

    It "exits non-zero for missing file" {
        & pwsh -NoProfile -NonInteractive -File $Validator -Path 'does-not-exist.json' 2>$null
        $LASTEXITCODE | Should -Not -Be 0
    }
}
