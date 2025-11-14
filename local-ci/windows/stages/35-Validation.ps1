#Requires -Version 7.0
param(
    [Parameter(Mandatory)]
    [pscustomobject]$Context
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$config = $Context.Config

function Set-StageStatus {
    param(
        [psobject]$Context,
        [string]$Status
    )
    if (-not $Context) { return }
    if ($Context.PSObject.Properties['StageStatus']) {
        $Context.StageStatus = $Status
    } else {
        $Context | Add-Member -NotePropertyName StageStatus -NotePropertyValue $Status -Force
    }
}

function Get-ConfigValue {
    param(
        [string]$Primary,
        [string]$Fallback = $null,
        $Default = $null
    )
    if ($Primary -and $config.PSObject.Properties[$Primary]) {
        return $config.$Primary
    }
    if ($Fallback -and $config.PSObject.Properties[$Fallback]) {
        return $config.$Fallback
    }
    return $Default
}

$enabledPropName = 'EnableValidationStage'
$enabledValue = Get-ConfigValue -Primary 'EnableValidationStage' -Fallback 'EnableViAnalyzerStage' -Default $false
if (-not $config.PSObject.Properties['EnableValidationStage'] -and $config.PSObject.Properties['EnableViAnalyzerStage']) {
    $enabledPropName = 'EnableViAnalyzerStage'
}
$enabled = [bool]$enabledValue
if (-not $enabled) {
    Write-Host ("[35-Validation] Stage disabled via config ({0}={1}); skipping." -f $enabledPropName, $enabledValue) -ForegroundColor Yellow
    Set-StageStatus -Context $Context -Status 'Skipped'
    return
}

$repoRoot = $Context.RepoRoot

function Resolve-RepoPath {
    param(
        [string]$Path,
        [switch]$AllowMissing
    )
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    if ([System.IO.Path]::IsPathRooted($Path)) {
        try { return (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath }
        catch {
            if ($AllowMissing) { return $Path }
            throw
        }
    }
    $candidate = Join-Path $repoRoot $Path
    try { return (Resolve-Path -LiteralPath $candidate -ErrorAction Stop).ProviderPath }
    catch {
        if ($AllowMissing) { return $candidate }
        throw
    }
}

function Resolve-Pwsh {
    $cmdInfo = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($cmdInfo) {
        if ($cmdInfo.PSObject.Properties['Path']) { return $cmdInfo.Path }
        if ($cmdInfo.PSObject.Properties['Source']) { return $cmdInfo.Source }
    }
    if ($IsWindows) {
        $candidate = Join-Path $PSHOME 'pwsh.exe'
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    return 'pwsh'
}

function Invoke-ValidationSuite {
    param(
        [string]$PwshPath,
        [string]$CfgPath,
        [int]$LvVersion,
        [int]$LvBitness
    )

    $scriptCandidates = [System.Collections.Generic.List[string]]::new()
    $customScript = Get-ConfigValue -Primary 'ValidationScriptPath' -Fallback 'MipSuiteScriptPath'
    if (-not [string]::IsNullOrWhiteSpace($customScript)) {
        $scriptCandidates.Add((Resolve-RepoPath -Path $customScript -AllowMissing))
    }
    $scriptCandidates.Add((Join-Path $repoRoot 'src' 'tools' 'icon-editor' 'Invoke-MissingInProjectSuite.ps1'))
    $scriptCandidates.Add((Join-Path $repoRoot 'tools' 'icon-editor' 'Invoke-MissingInProjectSuite.ps1'))

    $scriptPath = $scriptCandidates |
        Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } |
        Select-Object -First 1
    if (-not $scriptPath) {
        $checked = ($scriptCandidates | Where-Object { $_ } | Select-Object -Unique) -join ', '
        throw ("Invoke-MissingInProjectSuite.ps1 not found under repo; checked: {0}" -f $checked)
    }

    $resultsRoot = Get-ConfigValue -Primary 'ValidationResultsPath' -Fallback 'MipSuiteResultsPath' -Default 'tests/results'
    $resultsPath = Resolve-RepoPath -Path $resultsRoot -AllowMissing
    if (-not (Test-Path -LiteralPath $resultsPath)) {
        New-Item -ItemType Directory -Path $resultsPath -Force | Out-Null
    }

    $testSuite = (Get-ConfigValue -Primary 'ValidationTestSuite' -Fallback 'MipSuiteTestSuite' -Default 'compare')
    if ([string]::IsNullOrWhiteSpace($testSuite)) { $testSuite = 'compare' }
    $normalizedSuite = $testSuite.Trim().ToLowerInvariant()
    if ($normalizedSuite -notin @('compare','full')) {
        throw "[35-Validation] Invalid ValidationTestSuite value '$testSuite'. Expected 'compare' or 'full'."
    }

    $label = "validation-$($Context.Timestamp)"
    $arguments = @(
        '-NoLogo','-NoProfile','-File', $scriptPath,
        '-Label', $label,
        '-ResultsPath', $resultsPath,
        '-LabVIEWVersion', $LvVersion.ToString(),
        '-Bitness', $LvBitness,
        '-ViAnalyzerConfigPath', $CfgPath,
        '-ViAnalyzerVersion', $LvVersion,
        '-ViAnalyzerBitness', $LvBitness,
        '-TestSuite', $normalizedSuite
    )

    $requireReport = Get-ConfigValue -Primary 'ValidationRequireCompareReport' -Fallback 'MipSuiteRequireCompareReport' -Default $false
    if ($requireReport) {
        $arguments += '-RequireCompareReport'
    }

    $additionalArgs = Get-ConfigValue -Primary 'ValidationAdditionalArgs' -Fallback 'MipSuiteAdditionalArgs' -Default @()
    if ($additionalArgs) {
        foreach ($extra in $additionalArgs) {
            if (-not [string]::IsNullOrWhiteSpace($extra)) {
                $arguments += $extra
            }
        }
    }

    Write-Host ("[35-Validation] Running MissingInProject validation suite with analyzer config {0}" -f $CfgPath) -ForegroundColor Cyan
    & $PwshPath @arguments
}

$validationConfig = Get-ConfigValue -Primary 'ValidationConfigPath' -Fallback 'ViAnalyzerConfigPath'
if (-not $validationConfig) {
    throw "[35-Validation] ValidationConfigPath not set; specify the .viancfg file to use."
}
$cfgPath = Resolve-RepoPath -Path $validationConfig
if (-not (Test-Path -LiteralPath $cfgPath -PathType Leaf)) {
    throw "[35-Validation] Validation config not found at $cfgPath"
}

$pwsh = Resolve-Pwsh
$lvVersion = if ($config.PSObject.Properties['LabVIEWVersion']) { [int]$config.LabVIEWVersion } else { 2023 }
$lvBitness = if ($config.PSObject.Properties['LabVIEWBitness']) { [int]$config.LabVIEWBitness } else { 64 }

Invoke-ValidationSuite -PwshPath $pwsh -CfgPath $cfgPath -LvVersion $lvVersion -LvBitness $lvBitness
