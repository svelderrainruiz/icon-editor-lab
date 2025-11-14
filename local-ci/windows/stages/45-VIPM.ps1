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
if (-not $config.EnableVipmStage) {
    Write-Host "[45-VIPM] Stage disabled via config; skipping." -ForegroundColor Yellow
    Set-StageStatus -Context $Context -Status 'Skipped'
    return
}

$repoRoot = $Context.RepoRoot
$repairScript = Join-Path $repoRoot 'local-ci' 'windows' 'scripts' 'Repair-LVEnv.ps1'
if (-not (Test-Path -LiteralPath $repairScript -PathType Leaf)) {
    throw "Repair-LVEnv.ps1 not found at $repairScript"
}

function Resolve-RepoPath([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    if ([System.IO.Path]::IsPathRooted($Path)) { return (Resolve-Path -LiteralPath $Path).ProviderPath }
    $candidate = Join-Path $repoRoot $Path
    if (Test-Path -LiteralPath $candidate) { return (Resolve-Path -LiteralPath $candidate).ProviderPath }
    return $Path
}

$vipcPath = if ($env:LOCALCI_VIPM_VIPC) { $env:LOCALCI_VIPM_VIPC } else { $config.VipmVipcPath }
if (-not $config.VipmDisplayOnly) {
    $vipcPath = Resolve-RepoPath $vipcPath
    if (-not (Test-Path -LiteralPath $vipcPath -PathType Leaf)) {
        throw "VIPC file not found at $vipcPath"
    }
}

$relativePath = if ($config.VipmRelativePath) { $config.VipmRelativePath } else { 'src' }

$arguments = @(
    '-NoLogo','-NoProfile','-File', $repairScript,
    '-RelativePath', $relativePath
)
if ($config.VipmDisplayOnly) {
    $arguments += '-DisplayOnly'
} elseif ($vipcPath) {
    $arguments += @('-VipcPath', $vipcPath)
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

$pwsh = Resolve-Pwsh
Write-Host "[45-VIPM] Running Repair-LVEnv" -ForegroundColor Cyan
& $pwsh @arguments
