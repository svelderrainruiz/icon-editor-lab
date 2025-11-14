#requires -Version 7.0

$here = Split-Path -Parent $PSCommandPath
$repoRoot = (Resolve-Path (Join-Path $here '..' '..')).Path
$modulePath = Join-Path $repoRoot 'src/tools/icon-editor/IconEditorDevMode.psm1'
Import-Module $modulePath -Force

Describe 'Invoke-LabVIEWPrelaunchGuard' -Tag 'tools','icon-editor','devmode' {
    BeforeEach {
        $testRunRoot = Join-Path (Get-Item TestDrive:\).FullName 'run-root'
        if (-not (Test-Path -LiteralPath $testRunRoot -PathType Container)) {
            New-Item -ItemType Directory -Path $testRunRoot | Out-Null
        }

        Mock Invoke-IconEditorRogueCheck -ModuleName IconEditorDevMode { @{ Path = Join-Path $testRunRoot 'rogue.json' } }
        Mock Close-IconEditorLabVIEW -ModuleName IconEditorDevMode { }
        Mock Start-Sleep -ModuleName IconEditorDevMode { }
        Mock Get-Process -ModuleName IconEditorDevMode -ParameterFilter { $Name -eq 'LabVIEW' } { @() }
    }

    Context 'single running PID reported from settle' {
        It 'force closes the PID when AllowForceClose is set' {
            Mock Wait-IconEditorLabVIEWSettle -ModuleName IconEditorDevMode {
                [pscustomobject]@{
                    stage      = 'unit-test'
                    succeeded  = $false
                    runningPids= 1234
                }
            }

            Mock Stop-Process -ModuleName IconEditorDevMode { param($Id, $Force) } `
                -ParameterFilter { $Id -eq 1234 -and $Force }

            $threw = $false
            try {
                Invoke-LabVIEWPrelaunchGuard -RepoRoot $repoRoot -Stage 'unit-test' -RunRoot $testRunRoot -AllowForceClose
            } catch {
                $threw = $true
                $_.Exception.Message | Should -Be "Pre-launch settle failed for stage 'unit-test'."
            }
            $threw | Should -BeTrue
            Assert-MockCalled Stop-Process -ModuleName IconEditorDevMode -Times 1 -ParameterFilter { $Id -eq 1234 -and $Force }
        }

        It 'skips force close when AllowForceClose is not set' {
            Mock Wait-IconEditorLabVIEWSettle -ModuleName IconEditorDevMode {
                [pscustomobject]@{
                    stage      = 'unit-test'
                    succeeded  = $false
                    runningPids= 4321
                }
            }

            Mock Stop-Process -ModuleName IconEditorDevMode { param($Id, $Force) } `
                -ParameterFilter { $Id -eq 4321 }

            $threw = $false
            try {
                Invoke-LabVIEWPrelaunchGuard -RepoRoot $repoRoot -Stage 'unit-test' -RunRoot $testRunRoot
            } catch {
                $threw = $true
                $_.Exception.Message | Should -Be "Pre-launch settle failed for stage 'unit-test'."
            }
            $threw | Should -BeTrue
            Assert-MockCalled Stop-Process -ModuleName IconEditorDevMode -Times 0
        }
    }

    Context 'fast settle with force-close retry' {
        It 'uses fast timeout before force closing and succeeds on retry' {
            $testRunRoot = Join-Path (Get-Item TestDrive:\).FullName 'fast-settle-run'
            if (-not (Test-Path -LiteralPath $testRunRoot -PathType Container)) {
                New-Item -ItemType Directory -Path $testRunRoot | Out-Null
            }

            Mock Invoke-IconEditorRogueCheck -ModuleName IconEditorDevMode { }
            Mock Close-IconEditorLabVIEW -ModuleName IconEditorDevMode { }
            Mock Start-Sleep -ModuleName IconEditorDevMode { }
            Mock Get-Process -ModuleName IconEditorDevMode -ParameterFilter { $Name -eq 'LabVIEW' } { @() }

            $script:waitCallIndex = 0
            $script:waitCalls = New-Object System.Collections.Generic.List[object]
            $script:waitResponses = @(
                [pscustomobject]@{
                    stage       = 'unit-test-settle'
                    succeeded   = $false
                    runningPids = @(2468)
                },
                [pscustomobject]@{
                    stage     = 'unit-test-settle-retry'
                    succeeded = $true
                }
            )

            $expectedCalls = @(
                [pscustomobject]@{ Stage='unit-test-settle'; Timeout=12; Fast=6; Suppress=$true },
                [pscustomobject]@{ Stage='unit-test-settle-retry'; Timeout=24; Fast=0; Suppress=$false }
            )

            Mock Wait-IconEditorLabVIEWSettle -ModuleName IconEditorDevMode {
                param(
                    [string[]]$ExeCandidates,
                    [int]$TimeoutSeconds,
                    [int]$ExtraSleepSeconds,
                    [string]$Stage,
                    [switch]$SuppressWarning,
                    [int]$FastTimeoutSeconds
                )
                $callInfo = [pscustomobject]@{
                    Stage    = $Stage
                    Timeout  = $TimeoutSeconds
                    Fast     = $FastTimeoutSeconds
                    Suppress = [bool]$SuppressWarning
                }
                $script:waitCalls.Add($callInfo) | Out-Null
                $response = $script:waitResponses[$script:waitCallIndex]
                $script:waitCallIndex++
                return $response
            }

            Mock Stop-Process -ModuleName IconEditorDevMode {
                param($Id, [switch]$Force)
                $ids = @($Id)
                if (-not $Force -or -not ($ids -contains 2468)) {
                    throw "Unexpected Stop-Process parameters"
                }
            }

            $exception = $null
            try {
                Invoke-LabVIEWPrelaunchGuard -RepoRoot $repoRoot -Stage 'unit-test' -RunRoot $testRunRoot -AllowForceClose -SettleTimeoutSeconds 12 -SettleSleepSeconds 0
            } catch {
                $exception = $_
            }
            $exception | Should -BeNullOrEmpty

            $script:waitCalls.Count | Should -Be 2
            for ($i=0; $i -lt $script:waitCalls.Count; $i++) {
                $script:waitCalls[$i].Stage    | Should -Be $expectedCalls[$i].Stage
                $script:waitCalls[$i].Timeout  | Should -Be $expectedCalls[$i].Timeout
                $script:waitCalls[$i].Fast     | Should -Be $expectedCalls[$i].Fast
                $script:waitCalls[$i].Suppress | Should -Be $expectedCalls[$i].Suppress
            }
            Assert-MockCalled Stop-Process -ModuleName IconEditorDevMode -Times 1
        }
    }

    Context 'prepare script arguments' {
        It 'passes the Editor Packed Library build spec to PrepareIESource' {
            $testDrive = (Get-Item TestDrive:\).FullName
            $repoRoot = Join-Path $testDrive 'repo'
            $iconRoot = Join-Path $testDrive 'icon'
            $runRoot = Join-Path $testDrive 'run-root'
            foreach ($path in @($repoRoot, $iconRoot, $runRoot)) {
                if (-not (Test-Path -LiteralPath $path)) {
                    New-Item -ItemType Directory -Path $path | Out-Null
                }
            }

            $prepareDir = Join-Path $iconRoot '.github/actions/prepare-labview-source'
            $addTokenDir = Join-Path $iconRoot '.github/actions/add-token-to-labview'
            New-Item -ItemType Directory -Force -Path $prepareDir | Out-Null
            New-Item -ItemType Directory -Force -Path $addTokenDir | Out-Null
            $prepareScript = Join-Path $prepareDir 'Prepare_LabVIEW_source.ps1'
            $addTokenScript = Join-Path $addTokenDir 'AddTokenToLabVIEW.ps1'
            Set-Content -LiteralPath $prepareScript -Value 'param()'
            Set-Content -LiteralPath $addTokenScript -Value 'param()'
            New-Item -ItemType Directory -Force -Path (Join-Path $iconRoot 'resource/plugins') | Out-Null

            Mock Get-DefaultIconEditorDevModeTargets -ModuleName IconEditorDevMode { [pscustomobject]@{ Versions = @(2021); Bitness = @(64) } }
            Mock Test-IconEditorReliabilityOperation -ModuleName IconEditorDevMode { $false }
            Mock Invoke-IconEditorRogueCheck -ModuleName IconEditorDevMode
            Mock Invoke-LabVIEWPrelaunchGuard -ModuleName IconEditorDevMode
            Mock Invoke-LabVIEWRogueSweep -ModuleName IconEditorDevMode
            Mock Test-IconEditorDevelopmentMode -ModuleName IconEditorDevMode { [pscustomobject]@{ Entries = @() } }
            Mock Get-IconEditorLocalhostLibraryPath -ModuleName IconEditorDevMode { 'localhost-path' }
            Mock Close-IconEditorLabVIEW -ModuleName IconEditorDevMode
            Mock Assert-IconEditorDevModeTokenState -ModuleName IconEditorDevMode { [pscustomobject]@{ Entries = @() } }
            Mock Set-IconEditorDevModeState -ModuleName IconEditorDevMode { [pscustomobject]@{ Path = 'state.json'; Active = $true } }

            Mock Invoke-IconEditorDevModeScript -ModuleName IconEditorDevMode -ParameterFilter { $ScriptPath -like '*AddTokenToLabVIEW.ps1' } {
                param([string]$ScriptPath,[object[]]$ArgumentList,[string]$RepoRoot,[string]$IconEditorRoot,[string]$StageLabel)
            }

            $script:capturedPrepareArgs = $null
            Mock Invoke-IconEditorDevModeScript -ModuleName IconEditorDevMode -ParameterFilter { $ScriptPath -like '*Prepare_LabVIEW_source.ps1' } {
                param([string]$ScriptPath,[object[]]$ArgumentList,[string]$RepoRoot,[string]$IconEditorRoot,[string]$StageLabel)
                $script:capturedPrepareArgs = $ArgumentList
            }

            Enable-IconEditorDevelopmentMode `
                -RepoRoot $repoRoot `
                -IconEditorRoot $iconRoot `
                -Versions 2021 `
                -Bitness 64 `
                -RunRoot $runRoot `
                -AllowForceClose

            Assert-MockCalled Invoke-IconEditorDevModeScript -ModuleName IconEditorDevMode -Times 1 -ParameterFilter { $ScriptPath -like '*Prepare_LabVIEW_source.ps1' }
            $script:capturedPrepareArgs | Should -Not -BeNullOrEmpty
            $buildIndex = [Array]::IndexOf($script:capturedPrepareArgs, '-Build_Spec')
            $buildIndex | Should -BeGreaterOrEqual 0
            $script:capturedPrepareArgs[$buildIndex + 1] | Should -Be 'Editor Packed Library'
        }
    }

    Context 'version and bitness parameters' {
        BeforeAll {
            $script:testDrive = (Get-Item TestDrive:\).FullName
        }

        It 'passes versions and bitness to Close-IconEditorLabVIEW when settle fails' {
            $repoRoot = Join-Path $testDrive 'repo-version-coverage'
            $iconRoot = Join-Path $testDrive 'icon-version-coverage'
            $runRoot  = Join-Path $testDrive 'run-version-coverage'
            foreach ($path in @($repoRoot, $iconRoot, $runRoot)) {
                if (-not (Test-Path -LiteralPath $path)) {
                    New-Item -ItemType Directory -Path $path | Out-Null
                }
            }

            $script:settleStages = New-Object System.Collections.Generic.List[string]
            Mock Wait-IconEditorLabVIEWSettle -ModuleName IconEditorDevMode {
                param(
                    [string[]]$ExeCandidates,
                    [int]$TimeoutSeconds,
                    [int]$ExtraSleepSeconds,
                    [string]$Stage,
                    [switch]$SuppressWarning,
                    [int]$FastTimeoutSeconds
                )
                $script:settleStages.Add($Stage) | Out-Null
                if ($Stage -like '*retry') {
                    return [pscustomobject]@{ stage = $Stage; succeeded = $true }
                }
                return [pscustomobject]@{
                    stage       = $Stage
                    succeeded   = $false
                    runningPids = @(9876)
                }
            }

            Mock Close-IconEditorLabVIEW -ModuleName IconEditorDevMode {
                param([string]$RepoRoot,[string]$IconEditorRoot,[int[]]$Versions,[int[]]$Bitness,[string]$RunRoot)
            }

            Invoke-LabVIEWPrelaunchGuard `
                -RepoRoot $repoRoot `
                -IconEditorRoot $iconRoot `
                -Stage 'unit-test' `
                -Versions @(2023) `
                -Bitness @(64) `
                -RunRoot $runRoot

            Assert-MockCalled Close-IconEditorLabVIEW -ModuleName IconEditorDevMode -Times 1 -ParameterFilter {
                $Versions -and $Versions[0] -eq 2023 -and $Bitness -and $Bitness[0] -eq 64
            }
            $script:settleStages | Should -Contain 'unit-test-settle'
            $script:settleStages | Should -Contain 'unit-test-settle-retry'
        }

        It 'skips Close-IconEditorLabVIEW when bitness is not provided' {
            $repoRoot = Join-Path $testDrive 'repo-missing-bitness'
            $iconRoot = Join-Path $testDrive 'icon-missing-bitness'
            $runRoot  = Join-Path $testDrive 'run-missing-bitness'
            foreach ($path in @($repoRoot, $iconRoot, $runRoot)) {
                if (-not (Test-Path -LiteralPath $path)) {
                    New-Item -ItemType Directory -Path $path | Out-Null
                }
            }

            Mock Wait-IconEditorLabVIEWSettle -ModuleName IconEditorDevMode {
                param(
                    [string[]]$ExeCandidates,
                    [int]$TimeoutSeconds,
                    [int]$ExtraSleepSeconds,
                    [string]$Stage,
                    [switch]$SuppressWarning,
                    [int]$FastTimeoutSeconds
                )
                if ($Stage -like '*retry') {
                    return [pscustomobject]@{ stage = $Stage; succeeded = $true }
                }
                return [pscustomobject]@{
                    stage       = $Stage
                    succeeded   = $false
                    runningPids = @(2468)
                }
            }

            Mock Close-IconEditorLabVIEW -ModuleName IconEditorDevMode { }

            Invoke-LabVIEWPrelaunchGuard `
                -RepoRoot $repoRoot `
                -IconEditorRoot $iconRoot `
                -Stage 'unit-test' `
                -Versions @(2024) `
                -RunRoot $runRoot

            Assert-MockCalled Close-IconEditorLabVIEW -ModuleName IconEditorDevMode -Times 0
        }
    }

    Context 'build package operation' {
        It 'targets LabVIEW 2023 (32-bit) by default' {
            $testDrive = (Get-Item TestDrive:\).FullName
            $repoRoot = Join-Path $testDrive 'repo-buildpkg'
            $iconRoot = Join-Path $testDrive 'icon-buildpkg'
            $runRoot  = Join-Path $testDrive 'run-buildpkg'
            foreach ($path in @($repoRoot, $iconRoot, $runRoot)) {
                if (-not (Test-Path -LiteralPath $path)) {
                    New-Item -ItemType Directory -Path $path | Out-Null
                }
            }

            $prepareDir = Join-Path $iconRoot '.github/actions/prepare-labview-source'
            $addTokenDir = Join-Path $iconRoot '.github/actions/add-token-to-labview'
            New-Item -ItemType Directory -Force -Path $prepareDir | Out-Null
            New-Item -ItemType Directory -Force -Path $addTokenDir | Out-Null
            $prepareScript = Join-Path $prepareDir 'Prepare_LabVIEW_source.ps1'
            $addTokenScript = Join-Path $addTokenDir 'AddTokenToLabVIEW.ps1'
            Set-Content -LiteralPath $prepareScript -Value 'param()'
            Set-Content -LiteralPath $addTokenScript -Value 'param()'

            Mock Invoke-IconEditorRogueCheck -ModuleName IconEditorDevMode
            Mock Invoke-LabVIEWPrelaunchGuard -ModuleName IconEditorDevMode
            Mock Invoke-LabVIEWRogueSweep -ModuleName IconEditorDevMode
            Mock Test-IconEditorDevelopmentMode -ModuleName IconEditorDevMode { [pscustomobject]@{ Entries = @() } }
            Mock Get-IconEditorLocalhostLibraryPath -ModuleName IconEditorDevMode { 'localhost-path' }
            Mock Close-IconEditorLabVIEW -ModuleName IconEditorDevMode
            Mock Assert-IconEditorDevModeTokenState -ModuleName IconEditorDevMode { [pscustomobject]@{ Entries = @() } }
            Mock Set-IconEditorDevModeState -ModuleName IconEditorDevMode { [pscustomobject]@{ Path = 'state.json'; Active = $true } }

            Mock Invoke-IconEditorDevModeScript -ModuleName IconEditorDevMode -ParameterFilter { $ScriptPath -like '*AddTokenToLabVIEW.ps1' } {
                param([string]$ScriptPath,[object[]]$ArgumentList,[string]$RepoRoot,[string]$IconEditorRoot,[string]$StageLabel)
            }

            $script:capturedBuildPackageBitness = New-Object System.Collections.Generic.List[string]
            Mock Invoke-IconEditorDevModeScript -ModuleName IconEditorDevMode -ParameterFilter { $ScriptPath -like '*Prepare_LabVIEW_source.ps1' } {
                param([string]$ScriptPath,[object[]]$ArgumentList,[string]$RepoRoot,[string]$IconEditorRoot,[string]$StageLabel)
                $bitIndex = [Array]::IndexOf($ArgumentList, '-SupportedBitness')
                if ($bitIndex -ge 0 -and ($bitIndex + 1) -lt $ArgumentList.Count) {
                    $script:capturedBuildPackageBitness.Add($ArgumentList[$bitIndex + 1]) | Out-Null
                }
            }

            Enable-IconEditorDevelopmentMode `
                -RepoRoot $repoRoot `
                -IconEditorRoot $iconRoot `
                -Versions 2023 `
                -Operation 'BuildPackage' `
                -RunRoot $runRoot

            Assert-MockCalled Invoke-IconEditorDevModeScript -ModuleName IconEditorDevMode -Times 2 -ParameterFilter { $ScriptPath -like '*Prepare_LabVIEW_source.ps1' }
            $script:capturedBuildPackageBitness | Should -Contain '32'
            $script:capturedBuildPackageBitness | Should -Contain '64'
        }

        It 'respects explicit bitness selection when requesting 64-bit only' {
            $testDrive = (Get-Item TestDrive:\).FullName
            $repoRoot = Join-Path $testDrive 'repo-buildpkg-64'
            $iconRoot = Join-Path $testDrive 'icon-buildpkg-64'
            $runRoot  = Join-Path $testDrive 'run-buildpkg-64'
            foreach ($path in @($repoRoot, $iconRoot, $runRoot)) {
                if (-not (Test-Path -LiteralPath $path)) {
                    New-Item -ItemType Directory -Path $path | Out-Null
                }
            }

            $prepareDir = Join-Path $iconRoot '.github/actions/prepare-labview-source'
            $addTokenDir = Join-Path $iconRoot '.github/actions/add-token-to-labview'
            New-Item -ItemType Directory -Force -Path $prepareDir | Out-Null
            New-Item -ItemType Directory -Force -Path $addTokenDir | Out-Null
            $prepareScript = Join-Path $prepareDir 'Prepare_LabVIEW_source.ps1'
            $addTokenScript = Join-Path $addTokenDir 'AddTokenToLabVIEW.ps1'
            Set-Content -LiteralPath $prepareScript -Value 'param()'
            Set-Content -LiteralPath $addTokenScript -Value 'param()'

            Mock Invoke-IconEditorRogueCheck -ModuleName IconEditorDevMode
            Mock Invoke-LabVIEWPrelaunchGuard -ModuleName IconEditorDevMode
            Mock Invoke-LabVIEWRogueSweep -ModuleName IconEditorDevMode
            Mock Test-IconEditorDevelopmentMode -ModuleName IconEditorDevMode { [pscustomobject]@{ Entries = @() } }
            Mock Get-IconEditorLocalhostLibraryPath -ModuleName IconEditorDevMode { 'localhost-path' }
            Mock Close-IconEditorLabVIEW -ModuleName IconEditorDevMode
            Mock Assert-IconEditorDevModeTokenState -ModuleName IconEditorDevMode { [pscustomobject]@{ Entries = @() } }
            Mock Set-IconEditorDevModeState -ModuleName IconEditorDevMode { [pscustomobject]@{ Path = 'state.json'; Active = $true } }
            Mock Invoke-IconEditorDevModeScript -ModuleName IconEditorDevMode -ParameterFilter { $ScriptPath -like '*AddTokenToLabVIEW.ps1' } {
                param([string]$ScriptPath,[object[]]$ArgumentList,[string]$RepoRoot,[string]$IconEditorRoot,[string]$StageLabel)
            }

            $script:capturedSingleBitness = New-Object System.Collections.Generic.List[string]
            Mock Invoke-IconEditorDevModeScript -ModuleName IconEditorDevMode -ParameterFilter { $ScriptPath -like '*Prepare_LabVIEW_source.ps1' } {
                param([string]$ScriptPath,[object[]]$ArgumentList,[string]$RepoRoot,[string]$IconEditorRoot,[string]$StageLabel)
                $bitIndex = [Array]::IndexOf($ArgumentList, '-SupportedBitness')
                if ($bitIndex -ge 0 -and ($bitIndex + 1) -lt $ArgumentList.Count) {
                    $script:capturedSingleBitness.Add($ArgumentList[$bitIndex + 1]) | Out-Null
                }
            }

            Enable-IconEditorDevelopmentMode `
                -RepoRoot $repoRoot `
                -IconEditorRoot $iconRoot `
                -Versions 2023 `
                -Bitness 64 `
                -Operation 'BuildPackage' `
                -RunRoot $runRoot

            Assert-MockCalled Invoke-IconEditorDevModeScript -ModuleName IconEditorDevMode -Times 1 -ParameterFilter { $ScriptPath -like '*Prepare_LabVIEW_source.ps1' }
            $script:capturedSingleBitness.Count | Should -Be 1
            $script:capturedSingleBitness[0] | Should -Be '64'
        }
    }
}
