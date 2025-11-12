Describe "Close-LabVIEW.ps1" -Tag 'LVCompare','Unit' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\\..\\..')).Path
        $script:scriptPath = Join-Path $repoRoot 'src/tools/Close-LabVIEW.ps1'
        Test-Path -LiteralPath $script:scriptPath | Should -BeTrue
    }

    BeforeEach {
        $Global:CLICallLog = New-Object System.Collections.Generic.List[object]
    }

    AfterEach {
        Remove-Variable -Name CLICallLog -Scope Global -ErrorAction SilentlyContinue
        Remove-Item Env:LABVIEWCLI_PATH -ErrorAction SilentlyContinue
    }

    It 'returns provider/command in preview without executing' {
        Mock Import-Module { } # avoid loading real module
        function Global:Invoke-LVOperation {
            param([string]$Operation, [hashtable]$Params, [string]$Provider, [switch]$Preview)
            $Global:CLICallLog.Add([pscustomobject]@{ provider = 'labviewcli'; command = 'lvcli close'; preview = $Preview.IsPresent }) | Out-Null
            return [pscustomobject]@{ provider = 'labviewcli'; command = 'lvcli close'; exitCode = 0 }
        }

        $result = & $script:scriptPath -Preview -Provider 'auto'
        $result | Should -Not -BeNullOrEmpty
        $result.provider | Should -Be 'labviewcli'
        $result.command  | Should -Match 'close'
    }

    It 'treats no-running-instance stderr markers as success' {
        Mock Import-Module { }
        function Global:Invoke-LVOperation { param([string]$Operation,[hashtable]$Params,[string]$Provider,[switch]$Preview)
            return [pscustomobject]@{ provider = 'labviewcli'; command = 'close'; exitCode = 1; stderr = 'failed to establish a connection with LabVIEW' }
        }

        { & $script:scriptPath -Provider 'labviewcli' } | Should -Not -Throw
    }

    It 'throws on non-zero exit without known markers' {
        Mock Import-Module { }
        function Global:Invoke-LVOperation { param([string]$Operation,[hashtable]$Params,[string]$Provider,[switch]$Preview)
            return [pscustomobject]@{ provider = 'labviewcli'; command = 'close'; exitCode = 2; stderr = 'other error' }
        }

        { & $script:scriptPath -Provider 'labviewcli' } | Should -Throw '*exited with code 2*'
    }

    It 'overrides LABVIEWCLI_PATH during call and restores after' {
        $env:LABVIEWCLI_PATH = 'orig'
        Mock Import-Module { }
        function Global:Invoke-LVOperation { param([string]$Operation,[hashtable]$Params,[string]$Provider,[switch]$Preview)
            $Global:CLICallLog.Add([pscustomobject]@{ envCli = $env:LABVIEWCLI_PATH }) | Out-Null
            return [pscustomobject]@{ provider = 'labviewcli'; command = 'close'; exitCode = 0 }
        }

        & $script:scriptPath -LabVIEWCliPath 'override' -Provider 'labviewcli'
        $Global:CLICallLog.Count | Should -Be 1
        $Global:CLICallLog[0].envCli | Should -Be 'override'
        ($env:LABVIEWCLI_PATH ?? '') | Should -Be 'orig'
    }
}
