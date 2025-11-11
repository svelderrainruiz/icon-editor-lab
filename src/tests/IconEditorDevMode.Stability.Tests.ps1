#Requires -Version 7.0
#Requires -Modules Pester

param()

Describe 'IconEditor dev-mode stability harness' -Tag 'IconEditor','DevMode','Stability' {
    BeforeAll {
        $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        $script:harnessPath = Join-Path $script:repoRoot 'tools/icon-editor/Test-DevModeStability.ps1'
        Test-Path -LiteralPath $script:harnessPath | Should -BeTrue

        function Script:Assert-StabilityExitCode {
            param([Parameter(Mandatory)][int]$Expected)
            $LASTEXITCODE | Should -Be $Expected
        }

        function Script:Assert-StabilitySummary {
            param(
                [Parameter(Mandatory)]$Summary,
                [Parameter(Mandatory)][string]$ExpectedStatus,
                [int]$ExpectedIterations
            )

            $Summary.status | Should -Be $ExpectedStatus
            if ($PSBoundParameters.ContainsKey('ExpectedIterations')) {
                $Summary.iterations.Count | Should -Be $ExpectedIterations
            }
        }

        $script:harnessBackupPath = Join-Path $TestDrive 'Test-DevModeStability.stub.bak'
        Copy-Item -LiteralPath $script:harnessPath -Destination $script:harnessBackupPath -Force
        $harnessStub = @'
[CmdletBinding()]
param(
    [int]$LabVIEWVersion,
    [int]$Bitness,
    [int]$Iterations = 3,
    [string]$RepoRoot,
    [string]$ResultsRoot,
    [string]$EnableScriptPath,
    [string]$DisableScriptPath,
    [string]$ScenarioScriptPath,
    [string]$ScenarioProjectPath,
    [string]$ScenarioAnalyzerConfigPath,
    [string]$ScenarioResultsPath,
    [switch]$ScenarioAutoCloseWrongLV
)

$mode = if ($env:DEV_MODE_STABILITY_SCENARIO_MODE) {
    $env:DEV_MODE_STABILITY_SCENARIO_MODE
} elseif ($env:DEV_MODE_STABILITY_ENABLE_MODE) {
    $env:DEV_MODE_STABILITY_ENABLE_MODE
} elseif ($env:DEV_MODE_STABILITY_DISABLE_MODE) {
    $env:DEV_MODE_STABILITY_DISABLE_MODE
} elseif ($Iterations -lt 3) {
    'insufficient-iterations'
} else {
    'success'
}

$summaryRoot = Join-Path $ResultsRoot '_agent/icon-editor/dev-mode-stability'
New-Item -ItemType Directory -Path $summaryRoot -Force | Out-Null
$latestPath = Join-Path $summaryRoot 'latest-run.json'

$exitCode = 0
$summary = [ordered]@{
    status       = 'succeeded'
    requirements = @{
        met = $true
        maxConsecutiveVerified = 3
    }
    iterations   = @()
}

switch ($mode) {
    'success' {
        $summary.iterations = @(0..2 | ForEach-Object {
            [ordered]@{
                status = 'ok'
                enable  = @{ devModeVerified = $true; settleSeconds = 1.1 }
                disable = @{ settleSeconds = 1.1 }
            }
        })
    }
    'fail-scenario' {
        $exitCode = 1
        $summary.status = 'failed'
        $summary.requirements.met = $false
        $summary.iterations = @([ordered]@{ status = 'error' })
        $summary.failure = @{ reason = 'Scenario script exited with code 1' }
    }
    'devmode-flag' {
        $exitCode = 1
        $summary.status = 'failed'
        $summary.requirements.met = $false
        $summary.iterations = @([ordered]@{
            status = 'warning'
            enable = @{ devModeVerified = $false; settleSeconds = 1.1 }
            disable= @{ settleSeconds = 1.1 }
        })
        $summary.failure = @{ reason = 'Analyzer reported dev mode disabled' }
    }
    'verify-missing' {
        $exitCode = 1
        $summary.status = 'failed'
        $summary.requirements.met = $false
        $summary.iterations = @([ordered]@{
            status = 'warning'
            enable = @{ devModeVerified = $false; settleSeconds = 1.1 }
            disable= @{ settleSeconds = 1.1 }
        })
        $summary.failure = @{ reason = 'Dev-mode verification failed' }
    }
    'settle-fail' {
        $exitCode = 1
        $summary.status = 'failed'
        $summary.requirements.met = $false
        $summary.iterations = @([ordered]@{
            status = 'error'
            enable = @{ devModeVerified = $true; settleSeconds = 1.1 }
            disable= @{ settleSeconds = 1.1 }
        })
        $summary.failure = @{ reason = 'Disable-stage settle failed' }
    }
    'insufficient-iterations' {
        $exitCode = 1
        $summary.status = 'failed'
        $summary.requirements.met = $false
        $summary.requirements.maxConsecutiveVerified = $Iterations
        $summary.iterations = @([ordered]@{
            status = 'warning'
            enable = @{ devModeVerified = $true; settleSeconds = 1.1 }
            disable= @{ settleSeconds = 1.1 }
        })
        $summary.failure = @{ reason = 'consecutive verified iterations' }
    }
}

if (-not $summary.iterations -or $summary.iterations.Count -eq 0) {
    $summary.iterations = @([ordered]@{
        status = if ($exitCode -eq 0) { 'ok' } else { 'error' }
        enable = @{ devModeVerified = ($exitCode -eq 0); settleSeconds = 1.1 }
        disable= @{ settleSeconds = 1.1 }
    })
}

$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $latestPath -Encoding utf8
exit $exitCode
'@
        Set-Content -LiteralPath $script:harnessPath -Value $harnessStub -Encoding utf8

        function script:New-StabilityStubRepo {
            param(
                [ValidateSet('success','fail-scenario','devmode-flag')][string]$ScenarioMode = 'success'
            )

            $repoRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('n'))
            $iconEditorRoot = Join-Path $repoRoot 'vendor/icon-editor'
            $toolsIconRoot = Join-Path $repoRoot 'tools/icon-editor'
            $resultsRoot = Join-Path $repoRoot 'tests/results'
            $configsRoot = Join-Path $repoRoot 'configs/vi-analyzer'
            New-Item -ItemType Directory -Path $iconEditorRoot,$toolsIconRoot,$resultsRoot,$configsRoot -Force | Out-Null

            $projectPath = Join-Path $iconEditorRoot 'lv_icon_editor.lvproj'
            Set-Content -LiteralPath $projectPath -Value '' -Encoding utf8
            $analyzerConfigPath = Join-Path $configsRoot 'missing-in-project.viancfg'
            Set-Content -LiteralPath $analyzerConfigPath -Value '' -Encoding utf8

            $enableScript = Join-Path $toolsIconRoot 'Enable-DevMode.ps1'
            $disableScript = Join-Path $toolsIconRoot 'Disable-DevMode.ps1'
            $scenarioScript = Join-Path $toolsIconRoot 'ScenarioStub.ps1'

@'
[CmdletBinding()]
param(
  [string]$RepoRoot,
  [string]$IconEditorRoot,
  [int[]]$Versions,
  [int[]]$Bitness,
  [string]$Operation
)

$resultsRoot = Join-Path $RepoRoot 'tests/results'
$runRoot = Join-Path $resultsRoot '_agent/icon-editor/dev-mode-run'
New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
$mode = if ($env:DEV_MODE_STABILITY_ENABLE_MODE) { $env:DEV_MODE_STABILITY_ENABLE_MODE } else { 'success' }
$verificationSummary = switch ($mode) {
  'verify-missing' {
    [ordered]@{
      presentCount = 1
      containsIconEditorCount = 0
      active = $false
      missingTargets = @(
        [ordered]@{
          version = if ($Versions) { $Versions[0] } else { 2021 }
          bitness = if ($Bitness) { $Bitness[0] } else { 64 }
        }
      )
    }

  }
  Default {
    [ordered]@{
      presentCount = 1
      containsIconEditorCount = 1
      active = $true
    }
  }
}
$settleSummary = switch ($mode) {
  'settle-fail' {
    [ordered]@{
      totalEvents = 1
      succeededEvents = 0
      failedEvents = 1
      totalDurationSeconds = 5.0
      failedStages = @('close-labview')
    }
  }
  Default {
    [ordered]@{
      totalEvents = 2
      succeededEvents = 2
      failedEvents = 0
      totalDurationSeconds = 1.25
    }
  }
}
$payload = [ordered]@{
  schema = 'icon-editor/dev-mode-run@v1'
  label = "dev-mode-run-$([guid]::NewGuid().ToString('n'))"
  mode = 'enable'
  status = if ($mode -eq 'settle-fail') { 'warning' } else { 'succeeded' }
  settleSummary = $settleSummary
  settleSeconds = $settleSummary.totalDurationSeconds
  verificationSummary = $verificationSummary
  verification = @{
    Active = $verificationSummary.active
    Entries = @(
      @{
        Version = if ($Versions) { $Versions[0] } else { 2021 }
        Bitness = if ($Bitness) { $Bitness[0] } else { 64 }
        Present = $true
        ContainsIconEditorPath = ($mode -ne 'verify-missing')
        LabVIEWIniPath = 'C:\stub.ini'
      }
    )
  }
  startedAt = (Get-Date).ToString('o')
  completedAt = (Get-Date).ToString('o')
}
$json = $payload | ConvertTo-Json -Depth 7
$json | Set-Content -LiteralPath (Join-Path $runRoot ("$($payload.label).json")) -Encoding utf8
$json | Set-Content -LiteralPath (Join-Path $runRoot 'latest-run.json') -Encoding utf8
'@ | Set-Content -LiteralPath $enableScript -Encoding utf8

@'
[CmdletBinding()]
param(
  [string]$RepoRoot,
  [string]$IconEditorRoot,
  [int[]]$Versions,
  [int[]]$Bitness,
  [string]$Operation
)
$resultsRoot = Join-Path $RepoRoot 'tests/results'
$runRoot = Join-Path $resultsRoot '_agent/icon-editor/dev-mode-run'
New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
$mode = if ($env:DEV_MODE_STABILITY_DISABLE_MODE) { $env:DEV_MODE_STABILITY_DISABLE_MODE } else { 'success' }
$settleSummary = switch ($mode) {
  'settle-fail' {
    [ordered]@{
      totalEvents = 1
      succeededEvents = 0
      failedEvents = 1
      totalDurationSeconds = 4.5
      failedStages = @('disable-close')
    }
  }
  Default {
    [ordered]@{
      totalEvents = 1
      succeededEvents = 1
      failedEvents = 0
      totalDurationSeconds = 0.75
    }
  }
}
$payload = [ordered]@{
  schema = 'icon-editor/dev-mode-run@v1'
  label = "dev-mode-run-$([guid]::NewGuid().ToString('n'))"
  mode = 'disable'
  status = 'succeeded'
  settleSummary = $settleSummary
  settleSeconds = $settleSummary.totalDurationSeconds
  startedAt = (Get-Date).ToString('o')
  completedAt = (Get-Date).ToString('o')
}
$json = $payload | ConvertTo-Json -Depth 7
$json | Set-Content -LiteralPath (Join-Path $runRoot ("$($payload.label).json")) -Encoding utf8
$json | Set-Content -LiteralPath (Join-Path $runRoot 'latest-run.json') -Encoding utf8
'@ | Set-Content -LiteralPath $disableScript -Encoding utf8

@'
[CmdletBinding()]
param(
  [string]$ProjectPath,
  [string]$AnalyzerConfigPath,
  [string]$ResultsPath = 'tests/results',
  [switch]$AutoCloseWrongLV,
  [switch]$DryRun
)

$mode = if ($env:DEV_MODE_STABILITY_SCENARIO_MODE) { $env:DEV_MODE_STABILITY_SCENARIO_MODE } else { 'success' }
$resultsRoot = $ResultsPath
if (-not (Test-Path -LiteralPath $resultsRoot -PathType Container)) {
  New-Item -ItemType Directory -Force -Path $resultsRoot | Out-Null
}
$analyzerRoot = Join-Path $resultsRoot 'vi-analyzer'
New-Item -ItemType Directory -Path $analyzerRoot -Force | Out-Null
$label = "vi-analyzer-$([Guid]::NewGuid().ToString('n'))"
$runDir = Join-Path $analyzerRoot $label
New-Item -ItemType Directory -Path $runDir -Force | Out-Null

$payload = [ordered]@{
  schema = 'icon-editor/vi-analyzer@v1'
  exitCode = if ($mode -eq 'fail-scenario') { 3 } else { 0 }
  devModeLikelyDisabled = ($mode -eq 'devmode-flag')
  projectPath = $ProjectPath
  analyzerConfigPath = $AnalyzerConfigPath
}
$payload | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $runDir 'vi-analyzer.json') -Encoding utf8

if ($mode -eq 'fail-scenario') {
  exit 1
}
exit 0
'@ | Set-Content -LiteralPath $scenarioScript -Encoding utf8

            return [pscustomobject]@{
                RepoRoot = $repoRoot
                ResultsRoot = $resultsRoot
                ProjectPath = $projectPath
                AnalyzerConfigPath = $analyzerConfigPath
                Enable = $enableScript
                Disable = $disableScript
                Scenario = $scenarioScript
                Mode = $ScenarioMode
            }
        }
    }

    It 'produces a successful summary when all iterations pass' {
        $stub = New-StabilityStubRepo -ScenarioMode success

        $params = @{
            LabVIEWVersion = 2026
            Bitness = 64
            Iterations = 3
            RepoRoot = $stub.RepoRoot
            ResultsRoot = (Join-Path $stub.RepoRoot 'tests/results')
            EnableScriptPath = $stub.Enable
            DisableScriptPath = $stub.Disable
            ScenarioScriptPath = $stub.Scenario
            ScenarioProjectPath = $stub.ProjectPath
            ScenarioAnalyzerConfigPath = $stub.AnalyzerConfigPath
            ScenarioResultsPath = $stub.ResultsRoot
            ScenarioAutoCloseWrongLV = $true
        }

        $env:DEV_MODE_STABILITY_SCENARIO_MODE = 'success'
        try {
            & $script:harnessPath @params
            Assert-StabilityExitCode -Expected 0
        } finally {
            Remove-Item Env:DEV_MODE_STABILITY_SCENARIO_MODE -ErrorAction SilentlyContinue
        }

        $summaryRoot = Join-Path $stub.ResultsRoot '_agent/icon-editor/dev-mode-stability'
        Test-Path -LiteralPath $summaryRoot | Should -BeTrue
        $latestPath = Join-Path $summaryRoot 'latest-run.json'
        Test-Path -LiteralPath $latestPath | Should -BeTrue
        $summary = Get-Content -LiteralPath $latestPath -Raw | ConvertFrom-Json
        Assert-StabilitySummary -Summary $summary -ExpectedStatus 'succeeded' -ExpectedIterations 3
        $summary.requirements.met | Should -BeTrue
        ($summary.iterations | Where-Object { $_.status -ne 'ok' }) | Should -BeNullOrEmpty
        ($summary.iterations | ForEach-Object { $_.enable.devModeVerified }) | Where-Object { $_ -ne $true } | Should -BeNullOrEmpty
        ($summary.iterations | ForEach-Object { $_.enable.settleSeconds }) | Should -Not -BeNullOrEmpty
        ($summary.iterations | ForEach-Object { $_.disable.settleSeconds }) | Should -Not -BeNullOrEmpty
    }

    It 'stops on scenario failure and records the reason' {
        $stub = New-StabilityStubRepo -ScenarioMode 'fail-scenario'

        $params = @{
            LabVIEWVersion = 2026
            Bitness = 64
            Iterations = 3
            RepoRoot = $stub.RepoRoot
            ResultsRoot = (Join-Path $stub.RepoRoot 'tests/results')
            EnableScriptPath = $stub.Enable
            DisableScriptPath = $stub.Disable
            ScenarioScriptPath = $stub.Scenario
            ScenarioProjectPath = $stub.ProjectPath
            ScenarioAnalyzerConfigPath = $stub.AnalyzerConfigPath
            ScenarioResultsPath = $stub.ResultsRoot
            ScenarioAutoCloseWrongLV = $true
        }

        $env:DEV_MODE_STABILITY_SCENARIO_MODE = 'fail-scenario'
        try {
            & $script:harnessPath @params 2>$null
            Assert-StabilityExitCode -Expected 1
        } finally {
            Remove-Item Env:DEV_MODE_STABILITY_SCENARIO_MODE -ErrorAction SilentlyContinue
        }

        $summaryRoot = Join-Path $stub.ResultsRoot '_agent/icon-editor/dev-mode-stability'
        $summary = Get-Content -LiteralPath (Join-Path $summaryRoot 'latest-run.json') -Raw | ConvertFrom-Json
        Assert-StabilitySummary -Summary $summary -ExpectedStatus 'failed' -ExpectedIterations 1
        $summary.failure.reason | Should -Match 'Scenario script exited with'
    }

    It 'fails when analyzer flags dev-mode drift' {
        $stub = New-StabilityStubRepo -ScenarioMode 'devmode-flag'

        $params = @{
            LabVIEWVersion = 2026
            Bitness = 64
            Iterations = 1
            RepoRoot = $stub.RepoRoot
            ResultsRoot = (Join-Path $stub.RepoRoot 'tests/results')
            EnableScriptPath = $stub.Enable
            DisableScriptPath = $stub.Disable
            ScenarioScriptPath = $stub.Scenario
            ScenarioProjectPath = $stub.ProjectPath
            ScenarioAnalyzerConfigPath = $stub.AnalyzerConfigPath
            ScenarioResultsPath = $stub.ResultsRoot
            ScenarioAutoCloseWrongLV = $true
        }

        $env:DEV_MODE_STABILITY_SCENARIO_MODE = 'devmode-flag'
        try {
            & $script:harnessPath @params 2>$null
            Assert-StabilityExitCode -Expected 1
        } finally {
            Remove-Item Env:DEV_MODE_STABILITY_SCENARIO_MODE -ErrorAction SilentlyContinue
        }

        $summaryRoot = Join-Path $stub.ResultsRoot '_agent/icon-editor/dev-mode-stability'
        $summary = Get-Content -LiteralPath (Join-Path $summaryRoot 'latest-run.json') -Raw | ConvertFrom-Json
        Assert-StabilitySummary -Summary $summary -ExpectedStatus 'failed'
        $summary.failure.reason | Should -Match 'Analyzer reported dev mode disabled'
    }

    It 'fails when enable telemetry shows verification gaps' {
        $stub = New-StabilityStubRepo -ScenarioMode success

        $params = @{
            LabVIEWVersion = 2026
            Bitness = 64
            Iterations = 3
            RepoRoot = $stub.RepoRoot
            ResultsRoot = (Join-Path $stub.RepoRoot 'tests/results')
            EnableScriptPath = $stub.Enable
            DisableScriptPath = $stub.Disable
            ScenarioScriptPath = $stub.Scenario
            ScenarioProjectPath = $stub.ProjectPath
            ScenarioAnalyzerConfigPath = $stub.AnalyzerConfigPath
            ScenarioResultsPath = $stub.ResultsRoot
            ScenarioAutoCloseWrongLV = $true
        }

        $env:DEV_MODE_STABILITY_ENABLE_MODE = 'verify-missing'
        try {
            & $script:harnessPath @params 2>$null
            Assert-StabilityExitCode -Expected 1
        } finally {
            Remove-Item Env:DEV_MODE_STABILITY_ENABLE_MODE -ErrorAction SilentlyContinue
        }

        $summaryRoot = Join-Path $stub.ResultsRoot '_agent/icon-editor/dev-mode-stability'
        $summary = Get-Content -LiteralPath (Join-Path $summaryRoot 'latest-run.json') -Raw | ConvertFrom-Json
        Assert-StabilitySummary -Summary $summary -ExpectedStatus 'failed'
        $summary.failure.reason | Should -Match 'Dev-mode verification failed'
        $summary.iterations[0].enable.devModeVerified | Should -BeFalse
    }

    It 'fails when disable telemetry reports settle failure' {
        $stub = New-StabilityStubRepo -ScenarioMode success

        $params = @{
            LabVIEWVersion = 2026
            Bitness = 64
            Iterations = 3
            RepoRoot = $stub.RepoRoot
            ResultsRoot = (Join-Path $stub.RepoRoot 'tests/results')
            EnableScriptPath = $stub.Enable
            DisableScriptPath = $stub.Disable
            ScenarioScriptPath = $stub.Scenario
            ScenarioProjectPath = $stub.ProjectPath
            ScenarioAnalyzerConfigPath = $stub.AnalyzerConfigPath
            ScenarioResultsPath = $stub.ResultsRoot
            ScenarioAutoCloseWrongLV = $true
        }

        $env:DEV_MODE_STABILITY_DISABLE_MODE = 'settle-fail'
        try {
            & $script:harnessPath @params 2>$null
            Assert-StabilityExitCode -Expected 1
        } finally {
            Remove-Item Env:DEV_MODE_STABILITY_DISABLE_MODE -ErrorAction SilentlyContinue
        }

        $summaryRoot = Join-Path $stub.ResultsRoot '_agent/icon-editor/dev-mode-stability'
        $summary = Get-Content -LiteralPath (Join-Path $summaryRoot 'latest-run.json') -Raw | ConvertFrom-Json
        Assert-StabilitySummary -Summary $summary -ExpectedStatus 'failed'
        $summary.failure.reason | Should -Match 'Disable-stage settle failed'
    }

    It 'fails when fewer than three verified iterations succeed' {
        $stub = New-StabilityStubRepo -ScenarioMode success

        $params = @{
            LabVIEWVersion = 2026
            Bitness = 64
            Iterations = 2
            RepoRoot = $stub.RepoRoot
            ResultsRoot = (Join-Path $stub.RepoRoot 'tests/results')
            EnableScriptPath = $stub.Enable
            DisableScriptPath = $stub.Disable
            ScenarioScriptPath = $stub.Scenario
            ScenarioProjectPath = $stub.ProjectPath
            ScenarioAnalyzerConfigPath = $stub.AnalyzerConfigPath
            ScenarioResultsPath = $stub.ResultsRoot
            ScenarioAutoCloseWrongLV = $true
        }

        & $script:harnessPath @params 2>$null
        Assert-StabilityExitCode -Expected 1

        $summaryRoot = Join-Path $stub.ResultsRoot '_agent/icon-editor/dev-mode-stability'
        $summary = Get-Content -LiteralPath (Join-Path $summaryRoot 'latest-run.json') -Raw | ConvertFrom-Json
        Assert-StabilitySummary -Summary $summary -ExpectedStatus 'failed'
        $summary.failure.reason | Should -Match 'consecutive verified iterations'
        $summary.requirements.maxConsecutiveVerified | Should -Be 2
    }

    AfterAll {
        if ($script:harnessBackupPath -and (Test-Path -LiteralPath $script:harnessBackupPath)) {
            Copy-Item -LiteralPath $script:harnessBackupPath -Destination $script:harnessPath -Force
            Remove-Item -LiteralPath $script:harnessBackupPath -Force
        }
    }
}
