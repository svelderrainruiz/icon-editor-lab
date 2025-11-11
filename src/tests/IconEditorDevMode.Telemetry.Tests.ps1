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
