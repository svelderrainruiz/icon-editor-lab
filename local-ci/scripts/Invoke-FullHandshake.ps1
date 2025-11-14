#Requires -Version 7.0
[CmdletBinding()]
param(
    [switch]$SkipUbuntu,
    [switch]$SkipWindows,
    [switch]$SkipRender,
    [switch]$VerboseLogging
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    param([string]$Start = $PSScriptRoot)
    try {
        $resolved = git -C $Start rev-parse --show-toplevel 2>$null
        if ($resolved) { return $resolved.Trim() }
    } catch {}
    return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..' '..')).ProviderPath
}

function Convert-ToWslPath {
    param([Parameter(Mandatory)][string]$Path)
    $expanded = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
    $wslPath = & wsl.exe wslpath -a $expanded
    if ($LASTEXITCODE -ne 0 -or -not $wslPath) {
        throw "Failed to convert '$expanded' to a WSL path."
    }
    return $wslPath.Trim()
}

function Invoke-WslCommand {
    param(
        [Parameter(Mandatory)][string]$Command,
        [switch]$Echo
    )
    if ($Echo) {
        Write-Host "[WSL] $Command"
    }
    & wsl.exe bash -lc "$Command"
    if ($LASTEXITCODE -ne 0) {
        throw "WSL command failed with exit code $LASTEXITCODE (`"$Command`")."
    }
}

$repoRoot = Resolve-RepoRoot
$wslRepo = Convert-ToWslPath $repoRoot
$runsRoot = Join-Path $repoRoot 'out/local-ci-ubuntu'

if (-not $SkipUbuntu) {
    $cmd = "cd '$wslRepo' && ./local-ci/ubuntu/invoke-local-ci.sh"
    Invoke-WslCommand -Command $cmd -Echo:$VerboseLogging
}

if (-not (Test-Path -LiteralPath $runsRoot -PathType Container)) {
    throw "Ubuntu runs root not found at $runsRoot. Run the Ubuntu pipeline first."
}

$latestRun = Get-ChildItem -LiteralPath $runsRoot -Directory | Sort-Object Name -Descending | Select-Object -First 1
if (-not $latestRun) {
    throw "No Ubuntu runs detected under $runsRoot."
}
Write-Host ("[handshake] Selected Ubuntu run: {0}" -f $latestRun.FullName)

if (-not $SkipWindows) {
    $startScript = Join-Path $repoRoot 'local-ci/windows/scripts/Start-ImportedRun.ps1'
    if (-not (Test-Path -LiteralPath $startScript -PathType Leaf)) {
        throw "Start-ImportedRun.ps1 not found at $startScript"
    }
    & $startScript -UbuntuRunPath $latestRun.FullName
    if ($LASTEXITCODE -ne 0) {
        throw "Windows local CI failed with exit code $LASTEXITCODE."
    }
}

$runPublish = Join-Path $latestRun.FullName 'windows' 'vi-compare.publish.json'
if (-not (Test-Path -LiteralPath $runPublish -PathType Leaf)) {
    throw "Windows publish not found at $runPublish. Ensure stage 37 completed successfully."
}

if (-not $SkipRender) {
    $wslRun = Convert-ToWslPath $latestRun.FullName
    $wslPublish = Convert-ToWslPath $runPublish
    $cmd = @(
        "cd '$wslRepo'",
        "LOCALCI_REPO_ROOT='$wslRepo'",
        "LOCALCI_RUN_ROOT='$wslRun'",
        "LOCALCI_SIGN_ROOT='$wslRepo/out'",
        "LOCALCI_WINDOWS_PUBLISH_JSON='$wslPublish'",
        "bash local-ci/ubuntu/stages/45-vi-compare.sh"
    ) -join ' && '
    Invoke-WslCommand -Command $cmd -Echo:$VerboseLogging
}

Write-Host ""
Write-Host "Handshake complete."
Write-Host (" - Ubuntu run   : {0}" -f $latestRun.FullName)
if (-not $SkipWindows) {
    Write-Host (" - Windows publish: {0}" -f $runPublish)
}
if (-not $SkipRender) {
    Write-Host (" - Rendered HTML : {0}" -f (Join-Path $repoRoot ("out/vi-comparison/{0}/vi-comparison-report.html" -f $latestRun.Name)))
}
