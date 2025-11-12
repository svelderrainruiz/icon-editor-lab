function Global:New-CloseLvProcessMock {
        param(
            [bool]$WaitResult = $true,
            [int]$ExitCode = 0
        )

$proc = [pscustomobject]@{
    Id       = 4242
    ExitCode = $ExitCode
    HasExited = $WaitResult
        }

        $proc | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value {
            param([int]$Milliseconds)
            $this.HasExited
        } -Force

$proc | Add-Member -MemberType ScriptMethod -Name Kill -Value {
    param([bool]$Force)
    $Global:CloseLvKillCount++
} -Force

        return $proc
    }

Describe 'Close-LVCompare.ps1' -Tag 'LVCompare','Unit' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
        Set-Variable -Scope Script -Name closeScript -Value (Join-Path $repoRoot 'src/tools/Close-LVCompare.ps1')
        Test-Path -LiteralPath $script:closeScript | Should -BeTrue
    }

    BeforeEach {
        $script:lvComparePath = Join-Path $TestDrive 'LVCompare.exe'
        $script:labviewExePath = Join-Path $TestDrive 'LabVIEW.exe'
        $script:baseVi = Join-Path $TestDrive 'Base.vi'
        $script:headVi = Join-Path $TestDrive 'Head.vi'

        Set-Content -LiteralPath $script:lvComparePath -Value 'stub' -Encoding utf8
        Set-Content -LiteralPath $script:labviewExePath -Value 'stub' -Encoding utf8
        Set-Content -LiteralPath $script:baseVi -Value 'base' -Encoding utf8
        Set-Content -LiteralPath $script:headVi -Value 'head' -Encoding utf8

        $Global:CloseLvStartCalls = @()
        $Global:CloseLvKillCount = 0
    }

    It 'invokes LVCompare with default flags and resolved env paths' {
        Mock Start-Process {
            $Global:CloseLvStartCalls += [pscustomobject]@{
                FilePath    = $FilePath
                ArgumentList= $ArgumentList
            }
            return (New-CloseLvProcessMock -WaitResult $true)
        }

        $env:LVCOMPARE_PATH = $script:lvComparePath
        $env:LABVIEW_PATH   = $script:labviewExePath
        $env:LV_BASE_VI     = $script:baseVi
        $env:LV_HEAD_VI     = $script:headVi

        & $script:closeScript `
            -TimeoutSeconds 5 `
            -AdditionalArguments '-myflag' `
            | Out-Null

        $Global:CloseLvStartCalls.Count | Should -Be 1
        $call = $Global:CloseLvStartCalls[0]
        $call.FilePath | Should -Be $script:lvComparePath
        $call.ArgumentList | Should -Contain $script:baseVi
        $call.ArgumentList | Should -Contain $script:headVi
        $call.ArgumentList | Should -Contain '-lvpath'
        $call.ArgumentList | Should -Contain $script:labviewExePath
        $defaults = @('-noattr','-nofp','-nofppos','-nobd','-nobdcosm')
        foreach ($flag in $defaults) {
            $call.ArgumentList | Should -Contain $flag
        }
        $call.ArgumentList | Should -Contain '-myflag'
    }

    It 'kills the process when timeout hit and KillOnTimeout provided' {
        Mock Start-Process {
            $Global:CloseLvStartCalls += 1
            return (New-CloseLvProcessMock -WaitResult $false)
        }

        {
            & $script:closeScript `
                -LVComparePath $script:lvComparePath `
                -LabVIEWExePath $script:labviewExePath `
                -BaseVi $script:baseVi `
                -HeadVi $script:headVi `
                -TimeoutSeconds 1 `
                -KillOnTimeout
        } | Should -Throw '*did not exit within*'

        $Global:CloseLvKillCount | Should -Be 1
    }

    AfterEach {
        Remove-Item Env:LVCOMPARE_PATH -ErrorAction SilentlyContinue
        Remove-Item Env:LABVIEW_PATH -ErrorAction SilentlyContinue
        Remove-Item Env:LV_BASE_VI -ErrorAction SilentlyContinue
        Remove-Item Env:LV_HEAD_VI -ErrorAction SilentlyContinue
        Remove-Variable -Name CloseLvStartCalls -Scope Global -ErrorAction SilentlyContinue
        Remove-Variable -Name CloseLvKillCount -Scope Global -ErrorAction SilentlyContinue
    }

    AfterAll {
        Remove-Item Function:New-CloseLvProcessMock -ErrorAction SilentlyContinue
    }
}
