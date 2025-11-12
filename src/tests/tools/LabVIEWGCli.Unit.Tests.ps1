Describe "LabVIEWGCli module" -Tag 'LVCompare','Unit' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\\..\\..')).Path
        $script:modulePath = (Resolve-Path (Join-Path $repoRoot 'src/tools/LabVIEWGCli.psm1')).Path
        Test-Path -LiteralPath $script:modulePath | Should -BeTrue
        Import-Module -Name $script:modulePath -Force
    }

    AfterEach {
        Remove-Item env:LABVIEWGCLI_PATH -ErrorAction SilentlyContinue
    }

    Context 'Get-LabVIEWGCliPath' {
        It 'prefers the env override when present' {
            $env:LABVIEWGCLI_PATH = 'C:\custom\g-cli.exe'
            Get-LabVIEWGCliPath -Manager 'g-cli' | Should -Be 'C:\custom\g-cli.exe'
        }

        It 'resolves an injected candidate path before fallback' {
            $tempPath = Join-Path $env:TEMP ('gcli-fake-{0}.exe' -f ([guid]::NewGuid()))
            New-Item -ItemType File -Force -Path $tempPath | Out-Null
            try {
                Get-LabVIEWGCliPath -Manager 'labviewcli' -Candidates $tempPath | Should -Be (Resolve-Path $tempPath).Path
            } finally {
                Remove-Item -Force $tempPath
            }
        }

        It 'returns the manager token when discovery fails' {
            $missing = Join-Path $env:TEMP ('gcli-missing-{0}.exe' -f ([guid]::NewGuid()))
            Get-LabVIEWGCliPath -Manager 'vipm' -Candidates $missing | Should -Be 'vipm'
        }
    }

    Context 'Invoke-LabVIEWGCli' {
        It 'builds CLI arguments and respects flags' {
            $env:LABVIEWGCLI_PATH = 'C:\custom\g-cli.exe'
            $script:startParams = $null

            Mock Start-Process {
                param($FilePath, $ArgumentList, $NoNewWindow, $PassThru)
                $script:startParams = @{
                    FilePath      = $FilePath
                    ArgumentList  = $ArgumentList
                    NoNewWindow   = $NoNewWindow
                    PassThru      = $PassThru
                }
                return [pscustomobject]@{ Id = 101 }
            } -ModuleName 'LabVIEWGCli' -ParameterFilter { $FilePath -eq 'C:\custom\g-cli.exe' }

            $result = Invoke-LabVIEWGCli -Manager 'g-cli' -Command 'run' -NoSplash -AdditionalArguments 'foo','bar' -TimeoutSeconds 0

            $result.Path | Should -Be 'C:\custom\g-cli.exe'
            $result.Arguments | Should -Be @('run','-NoSplash','foo','bar')
            $result.ProcessId | Should -Be 101
            $script:startParams.FilePath | Should -Be 'C:\custom\g-cli.exe'
        }

        It 'kills the process when the timeout expires' {
            $env:LABVIEWGCLI_PATH = 'C:\custom\g-cli.exe'
            Mock Start-Process { [pscustomobject]@{ Id = 202 } } -ModuleName 'LabVIEWGCli' -ParameterFilter { $FilePath -eq 'C:\custom\g-cli.exe' }
            Mock Wait-Process { throw [System.TimeoutException]::new('timed out') } -ModuleName 'LabVIEWGCli'
            $script:stopArgs = $null
            Mock Stop-Process {
                param($Id, $Force)
                $script:stopArgs = @{ Id = $Id; Force = $Force }
            } -ModuleName 'LabVIEWGCli'

            { Invoke-LabVIEWGCli -TimeoutSeconds 1 } | Should -Throw
            $script:stopArgs.Id | Should -Be 202
            $script:stopArgs.Force | Should -BeTrue
        }
    }

    Context 'Invoke-GCliClose stub' {
        It 'returns metadata when closing via g-cli stub' {
            $result = Invoke-GCliClose -LabVIEWExePath 'C:\LabVIEW\LabVIEW.exe' -Arguments '-close'
            $result.LabVIEWExePath | Should -Be 'C:\LabVIEW\LabVIEW.exe'
            $result.Arguments | Should -Be '-close'
            $result.Message | Should -Match 'Stub g-cli close'
        }
    }
}
