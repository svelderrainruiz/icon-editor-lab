#Requires -Version 7.0
#Requires -Modules Pester

param()

Describe 'IconEditor dev-mode telemetry helpers' -Tag 'IconEditor','DevMode','Telemetry' {
    BeforeAll {
        $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        $script:modulePath = Join-Path $script:repoRoot 'tools/icon-editor/IconEditorDevMode.psm1'
        Import-Module $script:modulePath -Force
        $script:NewRogueSweepStub = {
            param(
                [switch]$IncludeRogue
            )

            $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('n'))
            $tools = Join-Path $root 'tools'
            New-Item -ItemType Directory -Path $tools -Force | Out-Null
            $results = Join-Path $root 'tests/results'
            New-Item -ItemType Directory -Path $results -Force | Out-Null

            $includeLiteral = if ($IncludeRogue) { '$true' } else { '$false' }
            $detectScript = @"
[CmdletBinding()]
param(
  [string]`$ResultsDir,
  [string]`$OutputPath,
  [int]`$LookBackSeconds,
  [switch]`$Quiet
)
if (-not (Test-Path -LiteralPath (Split-Path -Parent `$OutputPath) -PathType Container)) {
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent `$OutputPath) | Out-Null
}
`$payload = @{
  generatedAt = (Get-Date).ToString('o')
  rogue = @{
    labview   = @()
    lvcompare = @()
  }
}
if ($includeLiteral) {
  `$payload.rogue.labview = @(43210)
}
`$payload | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath `$OutputPath -Encoding utf8
"@
            Set-Content -LiteralPath (Join-Path $tools 'Detect-RogueLV.ps1') -Value $detectScript -Encoding utf8

            $closeLog = Join-Path $root 'close-log.txt'
            $closeContent = @"
[CmdletBinding()]
param()
Set-Content -LiteralPath '$closeLog' -Value (Get-Date).ToString('o') -Encoding utf8
"@
            Set-Content -LiteralPath (Join-Path $tools 'Close-LabVIEW.ps1') -Value $closeContent -Encoding utf8

            [pscustomobject]@{
                RepoRoot = $root
                ResultsRoot = $results
                CloseLog = $closeLog
            }
        }

        function Script:Assert-TelemetryOutcome {
            param(
                [Parameter(Mandatory)]$Payload,
                [Parameter(Mandatory)][string]$ExpectedMode,
                [Parameter(Mandatory)][string]$ExpectedStatus
            )

            $Payload.mode   | Should -Be $ExpectedMode
            $Payload.status | Should -Be $ExpectedStatus
        }
    }

    It 'captures settle summary and verification snapshot' {
        $repoRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('n'))
        New-Item -ItemType Directory -Force -Path $repoRoot | Out-Null

        $context = Initialize-IconEditorDevModeTelemetry -Mode 'enable' -RepoRoot $repoRoot -IconEditorRoot $repoRoot -Versions 2023 -Bitness 64 -Operation 'UnitTest'
        $context | Should -Not -BeNullOrEmpty
        $context.Mode | Should -Be 'enable'

        Invoke-IconEditorTelemetryStage -Context $context -Name 'sample-stage' -Action {
            param($stage)
            $events = @(
                [pscustomobject]@{
                    stage = 'sample-stage-settle'
                    succeeded = $true
                    durationSeconds = 1.23
                }
            )
            $stage | Add-Member -NotePropertyName 'settleEvents' -NotePropertyValue $events -Force
        }

        $state = [pscustomobject]@{
            Path = 'state.json'
            UpdatedAt = (Get-Date).ToString('o')
            Verification = [pscustomobject]@{
                Active = $true
                Entries = @(
                    [pscustomobject]@{
                        Version = 2023
                        Bitness = 64
                        Present = $true
                        ContainsIconEditorPath = $true
                        LabVIEWIniPath = 'C:\fake.ini'
                    }
                )
            }
        }

        Complete-IconEditorDevModeTelemetry -Context $context -Status 'succeeded' -State $state

        Test-Path -LiteralPath $context.TelemetryPath | Should -BeTrue
        Test-Path -LiteralPath $context.TelemetryLatestPath | Should -BeTrue

        $payload = Get-Content -LiteralPath $context.TelemetryPath -Raw | ConvertFrom-Json
        $expectedOutcome = @{ Mode = 'enable'; Status = 'succeeded' }
        Assert-TelemetryOutcome -Payload $payload -ExpectedMode $expectedOutcome.Mode -ExpectedStatus $expectedOutcome.Status
        $payload.statePath | Should -Be 'state.json'
        $payload.verificationSummary.presentCount | Should -Be 1
        $payload.verificationSummary.containsIconEditorCount | Should -Be 1
        $payload.settleSummary.totalEvents | Should -Be 1
        $payload.settleSummary.succeededEvents | Should -Be 1
        $payload.settleSummary.totalDurationSeconds | Should -BeGreaterThan 0
        $payload.stages.Count | Should -Be 1
    }

    It 'persists lv-addon root metadata to telemetry output' {
        $repoRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('n'))
        New-Item -ItemType Directory -Force -Path $repoRoot | Out-Null

        $context = Initialize-IconEditorDevModeTelemetry -Mode 'enable' -RepoRoot $repoRoot -IconEditorRoot $repoRoot -Versions 2024 -Bitness 32 -Operation 'UnitTest'
        $summary = [pscustomobject]@{
            Path = 'C:\icon-editor'
            Source = 'parameter'
            Mode = 'Strict'
            Origin = 'https://github.com/contributor/labview-icon-editor.git'
            Host = 'github.com'
            IsLVAddonLab = $true
            Contributor = 'telemetry-user'
        }

        $module = Get-Module -Name IconEditorDevMode
        & $module { param($ctx,$sum) Set-LvAddonRootTelemetry -TelemetryContext $ctx -Summary $sum } $context $summary

        Complete-IconEditorDevModeTelemetry -Context $context -Status 'succeeded'

        $payload = Get-Content -LiteralPath $context.TelemetryPath -Raw | ConvertFrom-Json
        $payload.lvAddonRootPath | Should -Be $summary.Path
        $payload.lvAddonRootSource | Should -Be $summary.Source
        $payload.lvAddonRootMode | Should -Be $summary.Mode
        $payload.lvAddonRootOrigin | Should -Be $summary.Origin
        $payload.lvAddonRootHost | Should -Be $summary.Host
        $payload.lvAddonRootIsLVAddonLab | Should -BeTrue
        $payload.lvAddonRootContributor | Should -Be $summary.Contributor
    }

    It 'records failures once and preserves settle errors' {
        $repoRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('n'))
        New-Item -ItemType Directory -Force -Path $repoRoot | Out-Null

        $context = Initialize-IconEditorDevModeTelemetry -Mode 'disable' -RepoRoot $repoRoot -IconEditorRoot $repoRoot -Versions 2021 -Bitness 32 -Operation 'UnitTest'
        Invoke-IconEditorTelemetryStage -Context $context -Name 'failing-stage' -Action {
            param($stage)
            $events = @(
                [pscustomobject]@{
                    stage = 'failing-settle'
                    succeeded = $false
                    error = 'timeout'
                    durationSeconds = 4.0
                }
            )
            $stage | Add-Member -NotePropertyName 'settleEvents' -NotePropertyValue $events -Force
        }

        Complete-IconEditorDevModeTelemetry -Context $context -Status 'failed' -Error 'boom'
        # Second call should no-op.
        Complete-IconEditorDevModeTelemetry -Context $context -Status 'succeeded'

        $payload = Get-Content -LiteralPath $context.TelemetryPath -Raw | ConvertFrom-Json
        $expectedOutcome = @{ Mode = 'disable'; Status = 'failed' }
        Assert-TelemetryOutcome -Payload $payload -ExpectedMode $expectedOutcome.Mode -ExpectedStatus $expectedOutcome.Status
        $payload.error | Should -Be 'boom'
        $payload.settleSummary.failedEvents | Should -Be 1
        $payload.settleSummary.failedStages | Should -Be 'failing-settle'
    }

    It 'derives a concise errorSummary from multi-line error text' {
        $repoRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('n'))
        New-Item -ItemType Directory -Force -Path $repoRoot | Out-Null

        $context = Initialize-IconEditorDevModeTelemetry -Mode 'enable' -RepoRoot $repoRoot -IconEditorRoot $repoRoot -Versions 2021 -Bitness 32 -Operation 'UnitTest'
        $errorText = @"
Dev-mode script 'AddTokenToLabVIEW.ps1' exited with code 1.
Error: No connection established with application.
Caused by: Timed out waiting for app to connect to g-cli
"@
        Complete-IconEditorDevModeTelemetry -Context $context -Status 'failed' -Error $errorText

        $payload = Get-Content -LiteralPath $context.TelemetryPath -Raw | ConvertFrom-Json
        $payload.error | Should -Be $errorText.TrimEnd()
        $payload.errorSummary | Should -Be 'Error: No connection established with application.'
    }

    It 'supports degraded status outcomes for partial failures' {
        $repoRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('n'))
        New-Item -ItemType Directory -Force -Path $repoRoot | Out-Null

        $context = Initialize-IconEditorDevModeTelemetry -Mode 'enable' -RepoRoot $repoRoot -IconEditorRoot $repoRoot -Versions 2025 -Bitness 64 -Operation 'UnitTest'
        $errorText = @"
Dev-mode simulation via x-cli for script 'AddTokenToLabVIEW.ps1' exited with code 2.
[x-cli] labview-devmode: partial failure for stage 'enable-addtoken-2025-64' (simulated, recoverable).
"@
        Complete-IconEditorDevModeTelemetry -Context $context -Status 'degraded' -Error $errorText

        $payload = Get-Content -LiteralPath $context.TelemetryPath -Raw | ConvertFrom-Json
        $expectedOutcome = @{ Mode = 'enable'; Status = 'degraded' }
        Assert-TelemetryOutcome -Payload $payload -ExpectedMode $expectedOutcome.Mode -ExpectedStatus $expectedOutcome.Status
        $payload.error | Should -Be $errorText.TrimEnd()
    }

    It 'classifies and summarizes x-cli timeout and partial-soft failures in telemetry' {
        $repoRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('n'))
        New-Item -ItemType Directory -Force -Path $repoRoot | Out-Null

        $scenarios = @(
            [pscustomobject]@{
                Name = 'partial-soft'
                ErrorText = @"
Dev-mode simulation via x-cli for script 'AddTokenToLabVIEW.ps1' exited with code 2.
[x-cli] labview-devmode: partial failure for stage 'enable-addtoken-2025-64' (simulated, recoverable).
"@
                ExpectedStatus = 'degraded'
                ExpectedSummary = 'Dev-mode simulation via x-cli for script ''AddTokenToLabVIEW.ps1'' exited with code 2.'
            },
            [pscustomobject]@{
                Name = 'timeout'
                ErrorText = @"
Dev-mode simulation via x-cli for script 'AddTokenToLabVIEW.ps1' exited with code 1.
Error: No connection established with application.
Caused by: Timed out waiting for app to connect to g-cli
"@
                ExpectedStatus = 'failed'
                ExpectedSummary = 'Error: No connection established with application.'
            }
        )

        foreach ($scenario in $scenarios) {
            $context = Initialize-IconEditorDevModeTelemetry -Mode 'enable' -RepoRoot $repoRoot -IconEditorRoot $repoRoot -Versions 2025 -Bitness 64 -Operation 'UnitTest'
            $status = Get-IconEditorDevModeOutcomeStatus -ErrorMessage $scenario.ErrorText
            Complete-IconEditorDevModeTelemetry -Context $context -Status $status -Error $scenario.ErrorText

            Test-Path -LiteralPath $context.TelemetryPath | Should -BeTrue
            $payload = Get-Content -LiteralPath $context.TelemetryPath -Raw | ConvertFrom-Json

            $payload.status | Should -Be $scenario.ExpectedStatus
            $payload.error | Should -Be $scenario.ErrorText.TrimEnd()
            $payload.errorSummary | Should -Be $scenario.ExpectedSummary
        }
    }

    Context 'Outcome classification helper' {
        It 'classifies x-cli partial failures as degraded' {
            $msg = @"
Dev-mode simulation via x-cli for script 'AddTokenToLabVIEW.ps1' exited with code 2.
[x-cli] labview-devmode: partial failure for stage 'enable-addtoken-2025-64' (simulated, recoverable).
"@
            $status = Get-IconEditorDevModeOutcomeStatus -ErrorMessage $msg
            $status | Should -Be 'degraded'
        }

        It 'classifies timeout errors as failed' {
            $msg = @"
Dev-mode simulation via x-cli for script 'AddTokenToLabVIEW.ps1' exited with code 1.
Error: No connection established with application.
Caused by: Timed out waiting for app to connect to g-cli
"@
            $status = Get-IconEditorDevModeOutcomeStatus -ErrorMessage $msg
            $status | Should -Be 'failed'
        }

        It 'classifies rogue-process errors as failed' {
            $msg = @"
Dev-mode simulation via x-cli for script 'Close_LabVIEW.ps1' exited with code 1.
Rogue LabVIEW processes detected during stage 'disable-close-2025-64'. See temp_telemetry/labview-devmode/rogue-sim.log for details.
"@
            $status = Get-IconEditorDevModeOutcomeStatus -ErrorMessage $msg
            $status | Should -Be 'failed'
        }

        It 'classifies generic simulated failures as failed' {
            $msg = "[x-cli] labview-devmode: failure in stage 'enable-addtoken-2025-64' (simulated)"
            $status = Get-IconEditorDevModeOutcomeStatus -ErrorMessage $msg
            $status | Should -Be 'failed'
        }
    }

    Context 'Invoke-LabVIEWRogueSweep' {
        It 'records sweep payload when no rogue processes remain' {
            $stub = & $script:NewRogueSweepStub
            $result = Invoke-LabVIEWRogueSweep -RepoRoot $stub.RepoRoot -Reason 'unit-test' -RequireClean
            $result | Should -Not -BeNullOrEmpty
            Test-Path -LiteralPath $result.path | Should -BeTrue
            $result.rogueLabVIEW | Should -BeNullOrEmpty
        }

        It 'throws when RequireClean detects rogue LabVIEW PIDs' {
            $stub = & $script:NewRogueSweepStub -IncludeRogue
            {
                Invoke-LabVIEWRogueSweep -RepoRoot $stub.RepoRoot -Reason 'unit-test-fail' -RequireClean | Out-Null
            } | Should -Throw -ErrorId *
            Test-Path -LiteralPath $stub.CloseLog | Should -BeTrue
        }
    }
}
