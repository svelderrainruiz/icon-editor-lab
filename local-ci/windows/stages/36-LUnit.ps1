#Requires -Version 7.0
param(
    [Parameter(Mandatory)]
    [pscustomobject]$Context
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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

$config = $Context.Config
if (-not $config.EnableMipLunitStage) {
    Write-Host ("[36-LUnit] Stage disabled via config (EnableMipLunitStage={0}); skipping." -f $config.EnableMipLunitStage) -ForegroundColor Yellow
    Set-StageStatus -Context $Context -Status 'Skipped'
    return
}

$repoRoot = $Context.RepoRoot
$scriptPath = Join-Path $repoRoot $config.MipLunitScriptPath
if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    throw "MipLunit script not found at $scriptPath"
}

function Resolve-RepoPath([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    if ([System.IO.Path]::IsPathRooted($Path)) { return (Resolve-Path -LiteralPath $Path).ProviderPath }
    $candidate = Join-Path $repoRoot $Path
    return (Resolve-Path -LiteralPath $candidate).ProviderPath
}

$resultsPath = Resolve-RepoPath $config.MipLunitResultsPath
if (-not $resultsPath) { $resultsPath = Join-Path $repoRoot 'tests/results' }
if (-not (Test-Path -LiteralPath $resultsPath)) { New-Item -ItemType Directory -Path $resultsPath -Force | Out-Null }

$anCfg = $config.MipLunitAnalyzerConfig
if ($anCfg) {
    $anCfg = Resolve-RepoPath $anCfg
}

$arguments = @(
    '-NoLogo','-NoProfile','-File', $scriptPath,
    '-ResultsPath', $resultsPath
)
if ($anCfg) {
    $arguments += @('-AnalyzerConfigPath', $anCfg)
}
if ($config.MipLunitAdditionalArgs) {
    foreach ($extra in $config.MipLunitAdditionalArgs) {
        if (-not [string]::IsNullOrWhiteSpace($extra)) { $arguments += $extra }
    }
}

$pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue)
if ($pwsh) {
    if ($pwsh.PSObject.Properties['Path']) { $pwsh = $pwsh.Path }
    elseif ($pwsh.PSObject.Properties['Source']) { $pwsh = $pwsh.Source }
}
if (-not $pwsh -and $IsWindows) {
    $candidate = Join-Path $PSHOME 'pwsh.exe'
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { $pwsh = $candidate }
}
if (-not $pwsh) { $pwsh = 'pwsh' }

Write-Host "[36-LUnit] Running $scriptPath" -ForegroundColor Cyan
& $pwsh @arguments
