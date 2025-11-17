#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Image,

    [string]$PlanPath = 'configs/validation/agent-validation-plan.json',

    [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoResolved = if ($RepoRoot) {
    (Resolve-Path -LiteralPath $RepoRoot -ErrorAction Stop).ProviderPath
} else {
    (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).ProviderPath
}

$planResolved = if ([System.IO.Path]::IsPathRooted($PlanPath)) {
    $PlanPath
} else {
    Join-Path $repoResolved $PlanPath
}
$planResolved = (Resolve-Path -LiteralPath $planResolved -ErrorAction Stop).ProviderPath
$planContainerPath = $planResolved
try {
    $relativePlan = [System.IO.Path]::GetRelativePath($repoResolved, $planResolved)
} catch {
    $relativePlan = $null
}
if ($relativePlan -and -not $relativePlan.StartsWith('..') -and -not [string]::IsNullOrWhiteSpace($relativePlan)) {
    $sanitized = $relativePlan -replace '\\','/'
    $planContainerPath = "/work/$sanitized"
} elseif ($relativePlan -eq '.') {
    $planContainerPath = '/work'
} else {
    Write-Warning ("Plan path '{0}' is outside the repo root '{1}'. Using host absolute path inside container." -f $planResolved, $repoResolved)
    $planContainerPath = $planResolved
}

$dockerArgs = @(
    'run','--rm',
    '-v',("${repoResolved}:/work"),
    '-w','/work',
    $Image,
    'pwsh','-NoLogo','-NoProfile',
    '-File','tools/validation/Invoke-AgentValidation.ps1',
    '-PlanPath',$planContainerPath
)

Write-Host ("[docker] Running agent validation in image '{0}'" -f $Image)
& docker @dockerArgs
