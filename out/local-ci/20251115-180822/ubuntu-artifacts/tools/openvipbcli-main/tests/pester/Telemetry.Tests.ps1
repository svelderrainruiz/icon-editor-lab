Describe "log-telemetry.ps1" {
    BeforeAll {
        $LogScript = Join-Path $PSScriptRoot "..\..\scripts\log-telemetry.ps1"
        $LogFile   = Join-Path $PSScriptRoot "..\..\telemetry\insight.log"
        if (Test-Path $LogFile) { Remove-Item $LogFile }
    }

    It "appends one line per call" {
        & $LogScript -Event "test" -Data @{foo="bar"}
        & $LogScript -Event "test2" -Data @{x=1}
        (Get-Content $LogFile).Count | Should -Be 2
    }
}
