Describe "LabVIEWLabVIEWCLI module" -Tag 'LVCompare','Unit' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\\..\\..')).Path
        $modulePath = (Resolve-Path (Join-Path $repoRoot 'src/tools/LabVIEWLabVIEWCLI.psm1')).Path
        Test-Path -LiteralPath $modulePath | Should -BeTrue
        Import-Module -Name $modulePath -Force
    }

    AfterEach {
        Remove-Item env:LABVIEWCLI_PATH -ErrorAction SilentlyContinue
    }

    Context 'Get-LabVIEWCliPath' {
        It 'respects env override' {
            $env:LABVIEWCLI_PATH = 'C:\LabVIEW\labviewcli.exe'
            Get-LabVIEWCliPath | Should -Be 'C:\LabVIEW\labviewcli.exe'
        }

        It 'resolves a provided candidate file' {
            $file = Join-Path $env:TEMP ('labviewcli-{0}.exe' -f ([guid]::NewGuid()))
            New-Item -ItemType File -Force -Path $file | Out-Null
            try {
                Get-LabVIEWCliPath -Candidates $file | Should -Be (Resolve-Path $file).Path
            } finally {
                Remove-Item -Force $file
            }
        }

        It 'falls back to the candidate token on failure' {
            Get-LabVIEWCliPath -Candidates 'missing-cli.exe' | Should -Be 'missing-cli.exe'
        }
    }

    Context 'Invoke-LabVIEWCli' {
        It 'builds CLI arguments and returns metadata' {
            $env:LABVIEWCLI_PATH = 'C:\LabVIEW\labviewcli.exe'
            $script:startMeta = $null
            Mock Start-Process {
                param($FilePath, $ArgumentList, $NoNewWindow, $PassThru)
                $script:startMeta = @{
                    FilePath     = $FilePath
                    ArgumentList = $ArgumentList
                }
                return [pscustomobject]@{ Id = 321 }
            } -ModuleName 'LabVIEWLabVIEWCLI' -ParameterFilter { $FilePath -eq 'C:\LabVIEW\labviewcli.exe' }

            $result = Invoke-LabVIEWCli -Command 'run' -NoSplash -AdditionalArguments 'foo','bar' -TimeoutSeconds 0

            $result.Path | Should -Be 'C:\LabVIEW\labviewcli.exe'
            $result.Arguments | Should -Be @('run','-NoSplash','foo','bar')
            $result.ProcessId | Should -Be 321
            $script:startMeta.ArgumentList | Should -Be @('run','-NoSplash','foo','bar')
        }

        It 'stops the process when timeout elapses' {
            $env:LABVIEWCLI_PATH = 'C:\LabVIEW\labviewcli.exe'
            Mock Start-Process { [pscustomobject]@{ Id = 333 } } -ModuleName 'LabVIEWLabVIEWCLI'
            Mock Wait-Process { throw [System.TimeoutException]::new('timed out') } -ModuleName 'LabVIEWLabVIEWCLI'
            $script:stopMeta = $null
            Mock Stop-Process {
                param($Id, $Force)
                $script:stopMeta = @{ Id = $Id; Force = $Force }
            } -ModuleName 'LabVIEWLabVIEWCLI'

            { Invoke-LabVIEWCli -TimeoutSeconds 1 } | Should -Throw
            $script:stopMeta.Id | Should -Be 333
            $script:stopMeta.Force | Should -BeTrue
        }
    }

    Context 'Invoke-LabVIEWCliClose stub' {
        It 'returns metadata with the message' {
            $result = Invoke-LabVIEWCliClose -LabVIEWExePath 'C:\LabVIEW\LabVIEW.exe' -Arguments '-close'
            $result.LabVIEWExePath | Should -Be 'C:\LabVIEW\LabVIEW.exe'
            $result.Arguments | Should -Be '-close'
            $result.Message | Should -Match '-close'
        }
    }
}
