#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet(
        'e2e.happy',
        'e2e.mip-lunit-fail',
        'e2e.mip-missing-vis+lvcompare-missing',
        'e2e.vipm-build',
        'e2e.vipm-build-no-artifacts',
        'e2e.vipm-build-display-only',
        'e2e.vipb-gcli-build'
    )]
    [string]$ScenarioFamily,
    [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..' '..') -ErrorAction Stop).ProviderPath
} else {
    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot -ErrorAction Stop).ProviderPath
}

Write-Host "[emulated] RepoRoot: $RepoRoot" -ForegroundColor DarkGray

$resultsRoot = Join-Path $RepoRoot 'tests' 'results'
if (-not (Test-Path -LiteralPath $resultsRoot -PathType Container)) {
    New-Item -ItemType Directory -Path $resultsRoot -Force | Out-Null
}

function Invoke-EmulatedDevMode {
    param(
        [string]$Scenario
    )

    Write-Host ("[emulated/devmode] Scenario='{0}'" -f $Scenario) -ForegroundColor Cyan

    $env:ICONEDITORLAB_PROVIDER = 'XCliSim'
    switch ($Scenario) {
        'devmode.success'          { $env:ICONEDITORLAB_SIM_SCENARIO = 'happy-path' }
        'devmode.timeout-hard'     { $env:ICONEDITORLAB_SIM_SCENARIO = 'timeout' }
        'devmode.timeout-soft'     { $env:ICONEDITORLAB_SIM_SCENARIO = 'timeout-soft' }
        'devmode.rogue'            { $env:ICONEDITORLAB_SIM_SCENARIO = 'rogue' }
        'devmode.partial-degraded' { $env:ICONEDITORLAB_SIM_SCENARIO = 'partial+timeout-soft' }
        'devmode.flaky'            { $env:ICONEDITORLAB_SIM_SCENARIO = 'retry-success.enable-addtoken-2021-32.v1' }
        default                    { $env:ICONEDITORLAB_SIM_SCENARIO = 'happy-path' }
    }

    try {
        # Emit a simple synthetic dev-mode-run payload without invoking LabVIEW.
        $runRoot = Join-Path $resultsRoot '_agent/icon-editor/dev-mode-run'
        if (-not (Test-Path -LiteralPath $runRoot -PathType Container)) {
            New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
        }
        $label = "dev-mode-run-$([guid]::NewGuid().ToString('n'))"
        $status = switch ($Scenario) {
            'devmode.success'          { 'succeeded' }
            'devmode.partial-degraded' { 'degraded' }
            'devmode.timeout-hard'     { 'failed' }
            'devmode.rogue'            { 'failed' }
            default                    { 'succeeded' }
        }
        $payload = [ordered]@{
            schema      = 'icon-editor/dev-mode-run@v1'
            label       = $label
            mode        = 'enable'
            status      = $status
            requestedVersions = @(2021)
            requestedBitness  = @(64)
            provider    = 'XCliSim-emulated'
            startedAt   = (Get-Date).ToString('o')
            completedAt = (Get-Date).ToString('o')
        }
        $json = $payload | ConvertTo-Json -Depth 6
        $json | Set-Content -LiteralPath (Join-Path $runRoot "$label.json") -Encoding utf8
        $json | Set-Content -LiteralPath (Join-Path $runRoot 'latest-run.json') -Encoding utf8
    } catch {
        Write-Warning ("[emulated/devmode] Dev-mode emulation failed: {0}" -f $_.Exception.Message)
    } finally {
        Remove-Item Env:ICONEDITORLAB_SIM_SCENARIO -ErrorAction SilentlyContinue
        Remove-Item Env:ICONEDITORLAB_PROVIDER -ErrorAction SilentlyContinue
    }
}

function Invoke-EmulatedStability {
    param(
        [string]$Scenario
    )

    Write-Host ("[emulated/stability] Scenario='{0}'" -f $Scenario) -ForegroundColor Cyan

    # Emit a synthetic stability summary instead of invoking the real harness.
    $stabilityRoot = Join-Path $resultsRoot '_agent/icon-editor/dev-mode-stability'
    if (-not (Test-Path -LiteralPath $stabilityRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $stabilityRoot -Force | Out-Null
    }

    $status = switch ($Scenario) {
        'success'      { 'succeeded' }
        'lunit-fail'   { 'failed' }
        'devmode-flag' { 'failed' }
        default        { 'failed' }
    }

    $summary = [ordered]@{
        status       = $status
        scenario     = $Scenario
        requirements = @{
            met = ($status -eq 'succeeded')
        }
        iterations   = @(
            [ordered]@{
                status = if ($status -eq 'succeeded') { 'ok' } else { 'error' }
                enable = @{
                    devModeVerified = ($status -eq 'succeeded')
                    settleSeconds   = 1.1
                }
                disable = @{
                    settleSeconds = 1.1
                }
            }
        )
    }

    if ($Scenario -eq 'lunit-fail') {
        $summary.status = 'failed'
        $summary.requirements.met = $false
        $summary.unit = @{
            status = 'failed'
            failed = 1
        }
        $summary.failure = @{ reason = 'LUnit run failed (emulated)' }
    } elseif ($Scenario -eq 'devmode-flag') {
        $summary.status = 'failed'
        $summary.requirements.met = $false
        $summary.failure = @{ reason = 'Dev-mode drift detected (emulated)' }
    }

    $json = $summary | ConvertTo-Json -Depth 6
    $json | Set-Content -LiteralPath (Join-Path $stabilityRoot 'latest-run.json') -Encoding utf8
}

function New-EmulatedMipReport {
    param(
        [string]$Kind  # mip.ok | mip.missing-vis
    )

    Write-Host ("[emulated/mip] Kind='{0}'" -f $Kind) -ForegroundColor Cyan

    $mipReportsDir = Join-Path $resultsRoot '_agent/reports/missing-in-project'
    if (-not (Test-Path -LiteralPath $mipReportsDir -PathType Container)) {
        New-Item -ItemType Directory -Path $mipReportsDir -Force | Out-Null
    }

    $label = "mip-emulated-{0}" -f (Get-Date -Format 'yyyyMMddTHHmmss')
    $reportPath = Join-Path $mipReportsDir ("{0}.json" -f $label)

    $extra = [ordered]@{}
    if ($Kind -eq 'mip.missing-vis') {
        $extra.missingTargets = @(
            [ordered]@{ path  = 'C:\src\Missing1.vi' },
            [ordered]@{ viPath = 'C:\src\Missing2.vi' }
        )
    }

    $payload = [ordered]@{
        schema  = 'icon-editor/report@v1'
        kind    = 'missing-in-project'
        label   = $label
        summary = if ($Kind -eq 'mip.missing-vis') { '2 missing VIs (emulated)' } else { 'no missing VIs (emulated)' }
    }
    if ($extra.Count -gt 0) { $payload.extra = $extra }

    $payload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $reportPath -Encoding utf8
    Write-Host ("[emulated/mip] Report written to: {0}" -f $reportPath) -ForegroundColor DarkGray
}

function New-EmulatedLvCompareReport {
    param(
        [string]$Kind  # lvcompare.ok | lvcompare.missing-capture
    )

    Write-Host ("[emulated/lvcompare] Kind='{0}'" -f $Kind) -ForegroundColor Cyan

    $lvReportsDir = Join-Path $resultsRoot '_agent/reports/lvcompare'
    if (-not (Test-Path -LiteralPath $lvReportsDir -PathType Container)) {
        New-Item -ItemType Directory -Path $lvReportsDir -Force | Out-Null
    }

    $label = "lvcompare-emulated-{0}" -f (Get-Date -Format 'yyyyMMddTHHmmss')
    $reportPath = Join-Path $lvReportsDir ("{0}.json" -f $label)

    $payload = [ordered]@{
        schema  = 'icon-editor/report@v1'
        kind    = 'lvcompare'
        label   = $label
        summary = if ($Kind -eq 'lvcompare.missing-capture') { 'capture missing (emulated)' } else { 'compare ok (emulated)' }
        extra   = [ordered]@{
            htmlReportPath = if ($Kind -eq 'lvcompare.ok') { 'C:\fake\lvcompare\compare-report.html' } else { $null }
            capturePath    = if ($Kind -eq 'lvcompare.ok') { 'C:\fake\lvcompare\lvcompare-capture.json' } else { $null }
        }
    }

    $payload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $reportPath -Encoding utf8
    Write-Host ("[emulated/lvcompare] Report written to: {0}" -f $reportPath) -ForegroundColor DarkGray
}

function New-EmulatedLUnitReport {
    param(
        [string]$Kind  # lunit.ok | lunit.fail
    )

    Write-Host ("[emulated/lunit] Kind='{0}'" -f $Kind) -ForegroundColor Cyan

    $unitReportsDir = Join-Path $resultsRoot '_agent/reports/unit-tests'
    if (-not (Test-Path -LiteralPath $unitReportsDir -PathType Container)) {
        New-Item -ItemType Directory -Path $unitReportsDir -Force | Out-Null
    }

    $label = "unit-tests-emulated-{0}" -f (Get-Date -Format 'yyyyMMddTHHmmss')
    $reportPath = Join-Path $unitReportsDir ("{0}.json" -f $label)

    $extra = [ordered]@{}
    if ($Kind -eq 'lunit.fail') {
        $extra.failedTests = @(
            [ordered]@{ name = 'Test_AddToken';  viPath = 'C:\src\tests\Test_AddToken.vi' },
            [ordered]@{ name = 'Test_PreparePPL'; viPath = $null },
            'Test_LegacyHelper'
        )
    } else {
        $extra.failedTests = @()
    }

    $payload = [ordered]@{
        schema  = 'icon-editor/report@v1'
        kind    = 'unit-tests'
        label   = $label
        summary = if ($Kind -eq 'lunit.fail') { 'LUnit: 3 failed tests (emulated)' } else { 'LUnit: all tests passed (emulated)' }
        extra   = $extra
    }

    $payload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $reportPath -Encoding utf8
    Write-Host ("[emulated/lunit] Report written to: {0}" -f $reportPath) -ForegroundColor DarkGray
}

function New-EmulatedViAnalyzerRun {
    param(
        [string]$Kind  # vianalyzer.labviewcli.ok | vianalyzer.labviewcli.devmode-drift | vianalyzer.labviewcli.fail
    )

    Write-Host ("[emulated/vianalyzer] Kind='{0}'" -f $Kind) -ForegroundColor Cyan

    $analyzerRoot = Join-Path $resultsRoot '_agent/vi-analyzer'
    if (-not (Test-Path -LiteralPath $analyzerRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $analyzerRoot -Force | Out-Null
    }

    $label = "vi-analyzer-emulated-{0}" -f (Get-Date -Format 'yyyyMMddTHHmmss')
    $runDir = Join-Path $analyzerRoot $label
    New-Item -ItemType Directory -Path $runDir -Force | Out-Null

    $exitCode = switch ($Kind) {
        'vianalyzer.labviewcli.ok'            { 0 }
        'vianalyzer.labviewcli.devmode-drift' { 1 }
        default                               { 3 }
    }

    $devModeDisabled = ($Kind -eq 'vianalyzer.labviewcli.devmode-drift')
    $failureCount    = if ($Kind -eq 'vianalyzer.labviewcli.fail') { 2 } else { 0 }

    $payload = [ordered]@{
        schema               = 'icon-editor/vi-analyzer@v1'
        tool                 = 'LabVIEWCLI'
        labviewVersion       = 2023
        bitness              = 64
        cliPath              = 'C:\fake\LabVIEWCLI.exe'
        configPath           = 'configs/vi-analyzer/missing-in-project.viancfg'
        exitCode             = $exitCode
        devModeLikelyDisabled = $devModeDisabled
        failureCount         = $failureCount
        reportPath           = (Join-Path $runDir 'vi-analyzer-report.html')
        cliLogPath           = (Join-Path $runDir 'vi-analyzer-cli.log')
    }

    if ($failureCount -gt 0) {
        $payload.failures = @(
            [ordered]@{ vi = 'C:\src\Bad1.vi'; test = 'Test_MissingDependency'; details = 'Dependency not found'; },
            [ordered]@{ vi = 'C:\src\Bad2.vi'; test = 'Test_BrokenVI';         details = 'VI is broken'; }
        )
    }

    $payload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $runDir 'vi-analyzer.json') -Encoding utf8
    Write-Host ("[emulated/vianalyzer] Telemetry written to: {0}" -f (Join-Path $runDir 'vi-analyzer.json')) -ForegroundColor DarkGray
}

function New-EmulatedVipmPackageRun {
    param(
        [string]$Kind,          # vipm.ok | vipm.no-artifacts | vipm.display-only | vipb-gcli.ok
        [string]$Toolchain = 'vipm',
        [string]$ProviderName = 'vipm-emulated'
    )

    Write-Host ("[emulated/vipm] Kind='{0}'" -f $Kind) -ForegroundColor Cyan

    $helpersPath = Join-Path $RepoRoot 'src/tools/icon-editor/VipmBuildHelpers.psm1'
    if (-not (Test-Path -LiteralPath $helpersPath -PathType Leaf)) {
        Write-Warning ("[emulated/vipm] VipmBuildHelpers.psm1 not found at '{0}'. Skipping telemetry emit." -f $helpersPath)
        return
    }

    try {
        Import-Module $helpersPath -Force | Out-Null
    } catch {
        Write-Warning ("[emulated/vipm] Failed to import VipmBuildHelpers module: {0}" -f $_.Exception.Message)
        return
    }

    try {
        $telemetryRoot = Initialize-VipmBuildTelemetry -RepoRoot $RepoRoot
    } catch {
        Write-Warning ("[emulated/vipm] Initialize-VipmBuildTelemetry failed: {0}" -f $_.Exception.Message)
        return
    }

    $resultsDir = Join-Path $resultsRoot '_agent/icon-editor/vipm-cli-build'
    if (-not (Test-Path -LiteralPath $resultsDir -PathType Container)) {
        New-Item -ItemType Directory -Path $resultsDir -Force | Out-Null
    }

    $started = Get-Date
    $artifacts = @()

    if ($Kind -eq 'vipm.ok' -or $Kind -eq 'vipb-gcli.ok') {
        $vipPath = Join-Path $resultsDir 'Emulated_Icon_editor-0.0.0.0.vip'
        'vipm-emulated-artifact' | Set-Content -LiteralPath $vipPath -Encoding utf8
        try {
            $file = Get-Item -LiteralPath $vipPath -ErrorAction Stop
            $artifact = [ordered]@{
                SourcePath       = $null
                DestinationPath  = $file.FullName
                Name             = $file.Name
                Kind             = 'vip'
                SizeBytes        = $file.Length
                LastWriteTimeUtc = $file.LastWriteTimeUtc.ToString('o')
            }
            $artifacts = @($artifact)
        } catch {
            Write-Warning ("[emulated/vipm] Failed to capture artifact metadata: {0}" -f $_.Exception.Message)
            $artifacts = @()
        }
    }

    $completed = Get-Date
    $metadata = [ordered]@{
        scenarioFamily = $ScenarioFamily
        scenarioKind   = $Kind
        emulated       = $true
        repoRoot       = $RepoRoot
    }

    try {
        if ($Kind -eq 'vipm.ok' -or $Kind -eq 'vipb-gcli.ok') {
            [void](Write-VipmBuildTelemetry `
                -LogRoot $telemetryRoot `
                -StartedAt $started `
                -CompletedAt $completed `
                -Toolchain $Toolchain `
                -Provider $ProviderName `
                -Artifacts $artifacts `
                -Metadata $metadata)
        } elseif ($Kind -eq 'vipm.display-only') {
            [void](Write-VipmBuildTelemetry `
                -LogRoot $telemetryRoot `
                -StartedAt $started `
                -CompletedAt $completed `
                -Toolchain $Toolchain `
                -Provider $ProviderName `
                -Metadata $metadata `
                -DisplayOnly)
        } else {
            [void](Write-VipmBuildTelemetry `
                -LogRoot $telemetryRoot `
                -StartedAt $started `
                -CompletedAt $completed `
                -Toolchain $Toolchain `
                -Provider $ProviderName `
                -Metadata $metadata)
        }
    } catch {
        Write-Warning ("[emulated/vipm] Write-VipmBuildTelemetry failed: {0}" -f $_.Exception.Message)
    }
}

switch ($ScenarioFamily) {
    'e2e.happy' {
        Invoke-EmulatedDevMode -Scenario 'devmode.success'
        Invoke-EmulatedStability -Scenario 'success'
        New-EmulatedViAnalyzerRun -Kind 'vianalyzer.labviewcli.ok'
        New-EmulatedMipReport -Kind 'mip.ok'
        New-EmulatedLvCompareReport -Kind 'lvcompare.ok'
        New-EmulatedLUnitReport -Kind 'lunit.ok'
    }
    'e2e.mip-lunit-fail' {
        Invoke-EmulatedDevMode -Scenario 'devmode.success'
        Invoke-EmulatedStability -Scenario 'lunit-fail'
        New-EmulatedViAnalyzerRun -Kind 'vianalyzer.labviewcli.ok'
        New-EmulatedMipReport -Kind 'mip.ok'
        New-EmulatedLvCompareReport -Kind 'lvcompare.ok'
        New-EmulatedLUnitReport -Kind 'lunit.fail'
    }
    'e2e.mip-missing-vis+lvcompare-missing' {
        Invoke-EmulatedDevMode -Scenario 'devmode.partial-degraded'
        Invoke-EmulatedStability -Scenario 'devmode-flag'
        New-EmulatedViAnalyzerRun -Kind 'vianalyzer.labviewcli.devmode-drift'
        New-EmulatedMipReport -Kind 'mip.missing-vis'
        New-EmulatedLvCompareReport -Kind 'lvcompare.missing-capture'
        New-EmulatedLUnitReport -Kind 'lunit.ok'
    }
    'e2e.vipm-build' {
        Invoke-EmulatedDevMode -Scenario 'devmode.success'
        Invoke-EmulatedStability -Scenario 'success'
        New-EmulatedVipmPackageRun -Kind 'vipm.ok'
    }
    'e2e.vipm-build-no-artifacts' {
        Invoke-EmulatedDevMode -Scenario 'devmode.success'
        Invoke-EmulatedStability -Scenario 'success'
        New-EmulatedVipmPackageRun -Kind 'vipm.no-artifacts'
    }
    'e2e.vipm-build-display-only' {
        Invoke-EmulatedDevMode -Scenario 'devmode.success'
        Invoke-EmulatedStability -Scenario 'success'
        New-EmulatedVipmPackageRun -Kind 'vipm.display-only'
    }
    'e2e.vipb-gcli-build' {
        Invoke-EmulatedDevMode -Scenario 'devmode.success'
        Invoke-EmulatedStability -Scenario 'success'
        New-EmulatedVipmPackageRun -Kind 'vipb-gcli.ok' -Toolchain 'vipb-gcli' -ProviderName 'vipb-gcli-emulated'
    }
}

Write-Host "[emulated] ScenarioFamily '$ScenarioFamily' complete." -ForegroundColor Green
