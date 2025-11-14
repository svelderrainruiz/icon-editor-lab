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

$repoRoot = $Context.RepoRoot
$tags = $Context.Config.HarnessTags
if (-not $tags -or $tags.Count -eq 0) {
    Write-Warning "No HarnessTags configured; skipping Pester run."
    Set-StageStatus -Context $Context -Status 'Skipped'
    return
}

$runner = Join-Path $repoRoot 'scripts' 'Invoke-RepoPester.ps1'
if (-not (Test-Path -LiteralPath $runner)) {
    throw "Pester runner not found at $runner"
}

Write-Host "Running Pester with tags: $($tags -join ', ')"
& $runner -Tag $tags -CI
