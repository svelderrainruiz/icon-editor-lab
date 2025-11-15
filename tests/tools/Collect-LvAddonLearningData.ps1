#Requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateSet('Enable','Disable','Both')]
    [string]$Actions = 'Enable',
    [string[]]$Scenarios = @(
        'happy-path',
        'timeout',
        'rogue',
        'timeout.enable-addtoken-2021-32.v2',
        'timeout-soft.enable-addtoken-2021-32.v2',
        'partial+timeout-soft.enable-addtoken-2021-32.v2',
        'retry-success.enable-addtoken-2021-32.v1',
        'lunit.enable-addtoken-2025-64.v1',
        'lunit.enable-prepare-2025-64.v1'
    ),
    [int]$MaxRecords = 25
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = $env:WORKSPACE_ROOT
if (-not $root) {
    $root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..' '..') -ErrorAction Stop).ProviderPath
}

Write-Host "[lvaddon/learn] Collecting LvAddon dev-mode learning data under: $root" -ForegroundColor DarkGray

$runDevModeScript = Join-Path $root 'tests/tools/Run-DevMode-Debug.ps1'
if (-not (Test-Path -LiteralPath $runDevModeScript -PathType Leaf)) {
    throw "[lvaddon/learn] Run-DevMode-Debug.ps1 not found at '$runDevModeScript'."
}

function Invoke-LvAddonDevModeXCliSim {
    param(
        [Parameter(Mandatory)][string]$Action,
        [Parameter(Mandatory)][string]$Scenario
    )

    Write-Host ("[lvaddon/learn] Scenario='{0}' Action='{1}'" -f $Scenario, $Action) -ForegroundColor Cyan

    $env:ICONEDITORLAB_PROVIDER = 'XCliSim'
    $env:ICONEDITORLAB_SIM_SCENARIO = $Scenario
    $previousRunId = $env:ICONEDITORLAB_RUN_ID
    $usingFlakyRunId = $false

    if ($Scenario -like 'retry-success*') {
        # Use a stable RunId for retry-success scenarios so that x-cli's
        # retry tracking can produce both failures and successes over time.
        if (-not $previousRunId) {
            $env:ICONEDITORLAB_RUN_ID = 'lvaddon-flaky-retry-success-enable-addtoken-2021-32'
        }
        $usingFlakyRunId = $true
    }

    try {
        pwsh -NoLogo -NoProfile -File $runDevModeScript -Action $Action -Provider XCliSim
    } catch {
        Write-Warning ("[lvaddon/learn] Dev-mode run failed for Scenario='{0}' Action='{1}': {2}" -f $Scenario, $Action, $_.Exception.Message)
    } finally {
        if ($usingFlakyRunId) {
            if ($null -ne $previousRunId) {
                $env:ICONEDITORLAB_RUN_ID = $previousRunId
            } else {
                Remove-Item Env:ICONEDITORLAB_RUN_ID -ErrorAction SilentlyContinue
            }
        }
        Remove-Item Env:ICONEDITORLAB_SIM_SCENARIO -ErrorAction SilentlyContinue
        Remove-Item Env:ICONEDITORLAB_PROVIDER -ErrorAction SilentlyContinue
    }
}

foreach ($scenario in $Scenarios | Where-Object { $_ }) {
    if ($Actions -eq 'Enable' -or $Actions -eq 'Both') {
        Invoke-LvAddonDevModeXCliSim -Action 'Enable' -Scenario $scenario
    }
    if ($Actions -eq 'Disable' -or $Actions -eq 'Both') {
        Invoke-LvAddonDevModeXCliSim -Action 'Disable' -Scenario $scenario
    }
}

$learningLoopScript = Join-Path $root 'tests/tools/Run-LvAddonLearningLoop.ps1'
if (-not (Test-Path -LiteralPath $learningLoopScript -PathType Leaf)) {
    Write-Warning "[lvaddon/learn] Run-LvAddonLearningLoop.ps1 not found; skipping learning snippet generation."
    return
}

Write-Host "[lvaddon/learn] Generating LvAddon learning summary and snippet..." -ForegroundColor DarkGray
pwsh -NoLogo -NoProfile -File $learningLoopScript -MaxRecords $MaxRecords
