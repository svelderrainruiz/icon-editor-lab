#Requires -Version 7.0

Set-StrictMode -Version Latest

Describe 'Invoke-VipmDependencies.ps1 argument handling' -Tag 'Unit','VipmDependencies' {
    BeforeAll {
        $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
        $script:scriptPath = Join-Path $script:repoRoot 'tools' 'icon-editor' 'Invoke-VipmDependencies.ps1'
        Test-Path -LiteralPath $script:scriptPath -PathType Leaf | Should -BeTrue
        $script:helperModulePath = Join-Path $script:repoRoot 'tools' 'icon-editor' 'VipmDependencyHelpers.psm1'
        Import-Module $script:helperModulePath -Force
    }

    BeforeEach {
        Push-Location $script:repoRoot
        Mock Import-Module -ParameterFilter {
            ($Name -and $Name -eq $script:helperModulePath) -or
            ($LiteralPath -and $LiteralPath -eq $script:helperModulePath)
        } -MockWith { }
        Mock Get-Process {
            [pscustomobject]@{ ProcessName = 'VI Package Manager'; Id = 9999 }
        }
        Mock Get-CimInstance { @() }
    }

    AfterEach {
        Pop-Location
    }

    It 'applies dependencies for each version/bitness combination via vipm-gcli' {
        $vipc = New-TemporaryFile
        Set-Content -LiteralPath $vipc -Value 'stub vipc'

        Mock Test-VipmCliReady { }
        Mock Install-VipmVipc {
            [pscustomobject]@{
                version  = $LabVIEWVersion
                bitness  = $LabVIEWBitness
                packages = @()
            }
        }

        & $script:scriptPath `
            -MinimumSupportedLVVersion 2021 `
            -VIP_LVVersion 2023 `
            -SupportedBitness '32,64' `
            -VIPCPath $vipc

        Assert-MockCalled Test-VipmCliReady -Times 4 -Exactly -ParameterFilter { $ProviderName -eq 'vipm-gcli' }
        Assert-MockCalled Install-VipmVipc -Times 4 -Exactly -ParameterFilter { $ProviderName -eq 'vipm-gcli' }
    }

    It 'lists packages via the vipm provider in display-only mode' {
        Mock Test-VipmCliReady { }
        Mock Install-VipmVipc { throw 'Install should not be invoked during DisplayOnly runs.' }
        Mock Show-VipmDependencies {
            [pscustomobject]@{
                version  = $LabVIEWVersion
                bitness  = $LabVIEWBitness
                packages = @()
            }
        }

        & $script:scriptPath `
            -MinimumSupportedLVVersion 2021 `
            -VIP_LVVersion 2023 `
            -SupportedBitness 32 `
            -DisplayOnly

        Assert-MockCalled Show-VipmDependencies -Times 2 -Exactly -ParameterFilter { $ProviderName -eq 'vipm' }
        Assert-MockCalled Test-VipmCliReady -Times 2 -Exactly -ParameterFilter { $ProviderName -eq 'vipm' }
    }

    It 'fails fast when VIPM is not running' {
        Mock Get-Process { @() }
        Mock Get-CimInstance { @() }

        {
            & $script:scriptPath -MinimumSupportedLVVersion 2021 -VIP_LVVersion 2023 -SupportedBitness 64 -VIPCPath (New-TemporaryFile)
        } | Should -Throw '*VIPM must be running*'
    }
}
