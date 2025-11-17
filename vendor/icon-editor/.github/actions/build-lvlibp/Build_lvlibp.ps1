#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$MinimumSupportedLVVersion,
    [string]$LabVIEWMinorRevision,
    [ValidateSet('32','64')]
    [string]$SupportedBitness = '64',
    [string]$RelativePath,
    [string]$IconEditorRoot,
    [int]$Major = 0,
    [int]$Minor = 0,
    [int]$Patch = 0,
    [int]$Build = 0,
    [string]$Commit,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArguments
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$candidateRoot = if ($IconEditorRoot) { $IconEditorRoot } elseif ($RelativePath) { $RelativePath } else { (Get-Location).ProviderPath }
try {
    $iconEditorRootResolved = (Resolve-Path -LiteralPath $candidateRoot -ErrorAction Stop).ProviderPath
} catch {
    $iconEditorRootResolved = [System.IO.Path]::GetFullPath($candidateRoot)
    New-Item -ItemType Directory -Path $iconEditorRootResolved -Force | Out-Null
}

$pluginsRoot = Join-Path $iconEditorRootResolved 'resource\plugins'
if (-not (Test-Path -LiteralPath $pluginsRoot -PathType Container)) {
    New-Item -ItemType Directory -Path $pluginsRoot -Force | Out-Null
}

$baseArtifact = Join-Path $pluginsRoot 'lv_icon.lvlibp'
$artifactMarker = "stub:{0}:{1}.{2}.{3}.{4}" -f $SupportedBitness, $Major, $Minor, $Patch, $Build
$artifactMarker | Set-Content -LiteralPath $baseArtifact -Encoding utf8

$summaryRoot = Join-Path $iconEditorRootResolved '.tmp-stubs'
if (-not (Test-Path -LiteralPath $summaryRoot -PathType Container)) {
    New-Item -ItemType Directory -Path $summaryRoot -Force | Out-Null
}

$summary = [ordered]@{
    schema        = 'icon-editor/build-lvlibp-stub@v1'
    timestamp     = (Get-Date).ToString('o')
    bitness       = $SupportedBitness
    repoRoot      = $iconEditorRootResolved
    commit        = $Commit
    version       = @{
        major = $Major
        minor = $Minor
        patch = $Patch
        build = $Build
    }
    minimumLv     = $MinimumSupportedLVVersion
    lvMinor       = $LabVIEWMinorRevision
    extraArgs     = $RemainingArguments
}
$summaryPath = Join-Path $summaryRoot ("build-lvlibp-{0}-{1}.json" -f $SupportedBitness, (Get-Date -Format 'yyyyMMdd-HHmmssfff'))
$summary | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $summaryPath -Encoding utf8

Write-Host "[build-lvlibp] Stubbed build for $SupportedBitness-bit. Artifact placed at $baseArtifact"
Write-Host "[build-lvlibp] Summary written to $summaryPath"
