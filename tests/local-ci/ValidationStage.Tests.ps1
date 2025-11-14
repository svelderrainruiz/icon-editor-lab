#Requires -Version 7.0

Describe 'local-ci/windows/stages/35-Validation.ps1' {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).ProviderPath
        $script:StagePath = Join-Path $script:RepoRoot 'local-ci/windows/stages/35-Validation.ps1'
        Test-Path -LiteralPath $script:StagePath | Should -BeTrue
    }

    It 'runs the validation suite with custom configuration' {
        $runRoot = Join-Path $TestDrive 'run-validation'
        $signRoot = Join-Path $TestDrive 'sign-validation'
        $resultsRoot = Join-Path $TestDrive 'validation-results'
        New-Item -ItemType Directory -Path $runRoot, $signRoot -Force | Out-Null

        $stub = Join-Path $TestDrive 'Invoke-ValidationStub.ps1'
        $stubContent = @'
param(
    [string]$Label,
    [string]$ResultsPath,
    [string]$LabVIEWVersion,
    [int]$Bitness,
    [string]$ViAnalyzerConfigPath,
    [int]$ViAnalyzerVersion,
    [int]$ViAnalyzerBitness,
    [string]$TestSuite,
    [switch]$RequireCompareReport,
    [switch]$IncludeNegative,
    [switch]$CleanResults
)
if (-not (Test-Path -LiteralPath $ResultsPath)) { New-Item -ItemType Directory -Path $ResultsPath -Force | Out-Null }
$payload = @{
    Label = $Label
    ResultsPath = $ResultsPath
    LabVIEWVersion = $LabVIEWVersion
    Bitness = $Bitness
    ViAnalyzerConfigPath = $ViAnalyzerConfigPath
    ViAnalyzerVersion = $ViAnalyzerVersion
    ViAnalyzerBitness = $ViAnalyzerBitness
    TestSuite = $TestSuite
    RequireCompareReport = [bool]$RequireCompareReport
    IncludeNegative = [bool]$IncludeNegative
    CleanResults = [bool]$CleanResults
}
$dest = Join-Path $ResultsPath 'validation-invocation.json'
$payload | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $dest -Encoding utf8
'@
        Set-Content -LiteralPath $stub -Value $stubContent -Encoding utf8

        $cfgPath = Join-Path $TestDrive 'validation.viancfg'
        Set-Content -LiteralPath $cfgPath -Value '<VIAnalyzer></VIAnalyzer>' -Encoding utf8

        $context = [pscustomobject]@{
            RepoRoot  = $script:RepoRoot
            RunRoot   = $runRoot
            SignRoot  = $signRoot
            Timestamp = 'UNIT-VAL-1'
            Config    = [pscustomobject]@{
                EnableValidationStage       = $true
                ValidationScriptPath        = $stub
                ValidationConfigPath        = $cfgPath
                ValidationResultsPath       = $resultsRoot
                ValidationTestSuite         = 'full'
                ValidationRequireCompareReport = $true
                ValidationAdditionalArgs    = @('-IncludeNegative','-CleanResults')
                LabVIEWVersion              = 2025
                LabVIEWBitness              = 32
            }
        }

        & $script:StagePath -Context $context

        $invocationPath = Join-Path $resultsRoot 'validation-invocation.json'
        Test-Path -LiteralPath $invocationPath -PathType Leaf | Should -BeTrue
        $invocation = Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json
        $invocation.Label | Should -Be 'validation-UNIT-VAL-1'
        $invocation.ResultsPath | Should -Be $resultsRoot
        $invocation.TestSuite | Should -Be 'full'
        $invocation.RequireCompareReport | Should -BeTrue
        $invocation.IncludeNegative | Should -BeTrue
        $invocation.CleanResults | Should -BeTrue
        $invocation.ViAnalyzerConfigPath | Should -Be $cfgPath
        $invocation.ViAnalyzerVersion | Should -Be 2025
        $invocation.ViAnalyzerBitness | Should -Be 32
        $invocation.LabVIEWVersion | Should -Be '2025'
    }

    It 'supports legacy configuration keys for compatibility' {
        $runRoot = Join-Path $TestDrive 'run-legacy'
        $signRoot = Join-Path $TestDrive 'sign-legacy'
        $resultsRoot = Join-Path $TestDrive 'legacy-results'
        New-Item -ItemType Directory -Path $runRoot, $signRoot -Force | Out-Null

        $stub = Join-Path $TestDrive 'Invoke-ValidationLegacyStub.ps1'
        $stubContent = @'
param(
    [string]$Label,
    [string]$ResultsPath,
    [string]$LabVIEWVersion,
    [int]$Bitness,
    [string]$ViAnalyzerConfigPath,
    [int]$ViAnalyzerVersion,
    [int]$ViAnalyzerBitness,
    [string]$TestSuite
)
$payload = @{
    Label = $Label
    ResultsPath = $ResultsPath
    ViAnalyzerConfigPath = $ViAnalyzerConfigPath
    TestSuite = $TestSuite
}
$dest = Join-Path $ResultsPath 'validation-legacy.json'
$payload | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $dest -Encoding utf8
'@
        Set-Content -LiteralPath $stub -Value $stubContent -Encoding utf8

        $cfgPath = Join-Path $TestDrive 'legacy.viancfg'
        Set-Content -LiteralPath $cfgPath -Value '<VIAnalyzer></VIAnalyzer>' -Encoding utf8

        $context = [pscustomobject]@{
            RepoRoot  = $script:RepoRoot
            RunRoot   = $runRoot
            SignRoot  = $signRoot
            Timestamp = 'UNIT-LEG-1'
            Config    = [pscustomobject]@{
                EnableViAnalyzerStage = $true
                ViAnalyzerConfigPath  = $cfgPath
                MipSuiteScriptPath    = $stub
                MipSuiteResultsPath   = $resultsRoot
                MipSuiteTestSuite     = 'compare'
                LabVIEWVersion        = 2023
                LabVIEWBitness        = 64
            }
        }

        & $script:StagePath -Context $context

        $invocationPath = Join-Path $resultsRoot 'validation-legacy.json'
        Test-Path -LiteralPath $invocationPath -PathType Leaf | Should -BeTrue
        $invocation = Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json
        $invocation.Label | Should -Be 'validation-UNIT-LEG-1'
        $invocation.ResultsPath | Should -Be $resultsRoot
        $invocation.ViAnalyzerConfigPath | Should -Be $cfgPath
        $invocation.TestSuite | Should -Be 'compare'
    }

    It 'skips when validation is disabled' {
        $runRoot = Join-Path $TestDrive 'run-disabled'
        $signRoot = Join-Path $TestDrive 'sign-disabled'
        $resultsRoot = Join-Path $TestDrive 'disabled-results'
        New-Item -ItemType Directory -Path $runRoot, $signRoot -Force | Out-Null

        $stub = Join-Path $TestDrive 'Invoke-ValidationDisabled.ps1'
        Set-Content -LiteralPath $stub -Value 'param()' -Encoding utf8
        $cfgPath = Join-Path $TestDrive 'disabled.viancfg'
        Set-Content -LiteralPath $cfgPath -Value '<VIAnalyzer></VIAnalyzer>' -Encoding utf8

        $context = [pscustomobject]@{
            RepoRoot  = $script:RepoRoot
            RunRoot   = $runRoot
            SignRoot  = $signRoot
            Timestamp = 'UNIT-DIS-1'
            Config    = [pscustomobject]@{
                EnableValidationStage = $false
                ValidationScriptPath  = $stub
                ValidationConfigPath  = $cfgPath
                ValidationResultsPath = $resultsRoot
            }
        }

        & $script:StagePath -Context $context

        $invocationPath = Join-Path $resultsRoot 'validation-invocation.json'
        Test-Path -LiteralPath $invocationPath -PathType Leaf | Should -BeFalse
    }
}
