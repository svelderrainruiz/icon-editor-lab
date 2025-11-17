Describe "rotate-telemetry.ps1" {
    BeforeAll {
        $Script = Join-Path $PSScriptRoot "..\..\scripts\rotate-telemetry.ps1"
        $TelemetryDir = Join-Path $PSScriptRoot "..\..\telemetry"
        if (Test-Path $TelemetryDir) { Remove-Item -Recurse -Force $TelemetryDir }
    }

    It "does nothing when log file is missing" {
        & $Script -MaxSizeMB 1
        # no exception, no files created
        (Test-Path $TelemetryDir) | Should -BeFalse
    }

    It "rotates when log exceeds threshold" {
        if (-not (Test-Path $TelemetryDir)) { New-Item -ItemType Directory -Path $TelemetryDir | Out-Null }
        $log = Join-Path $TelemetryDir "insight.log"
        # create a >1MB file
        $data = 'X' * (1MB + 1)
        Set-Content -Path $log -Value $data -Encoding ASCII

        & $Script -MaxSizeMB 1

        # now we should have at least one rotated file
        (Get-ChildItem $TelemetryDir -Filter "insight.log.*").Count | Should -BeGreaterThan 0
    }
}
