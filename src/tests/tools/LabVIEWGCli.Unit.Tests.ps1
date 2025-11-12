Describe "LabVIEWGCli module" -Tag 'LVCompare','Unit' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\\..\\..')).Path
        $script:modulePath = Join-Path $repoRoot 'src/tools/LabVIEWGCli.psm1'
        Test-Path -LiteralPath $script:modulePath | Should -BeTrue
        Import-Module $script:modulePath -Force
    }

    It 'returns metadata when closing via g-cli stub' {
        $result = Invoke-GCliClose -LabVIEWExePath 'C:\LabVIEW\LabVIEW.exe' -Arguments '-close'
        $result.LabVIEWExePath | Should -Be 'C:\LabVIEW\LabVIEW.exe'
        $result.Arguments | Should -Be '-close'
        $result.Message | Should -Match 'Stub g-cli close'
    }
}
