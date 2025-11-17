#Requires -Version 7.0
[CmdletBinding()]
param(
    [int]$MinimumSupportedLVVersion,
    [ValidateSet('32','64')]
    [string]$SupportedBitness = '64',
    [string]$IconEditorRoot,
    [int]$VIP_LVVersion,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$AdditionalArguments
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$resolvedRoot = if ($IconEditorRoot) {
    (Resolve-Path -LiteralPath $IconEditorRoot -ErrorAction Stop).ProviderPath
} else {
    Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
}

$statusFile = Join-Path $resolvedRoot (".tmp-stubs\vipc-apply-{0}-{1}.txt" -f $MinimumSupportedLVVersion, $SupportedBitness)
New-Item -ItemType Directory -Path (Split-Path -Parent $statusFile) -Force | Out-Null
"vipc-apply:$MinimumSupportedLVVersion:$SupportedBitness" | Set-Content -LiteralPath $statusFile -Encoding utf8

Write-Host ("[apply-vipc] Stubbed VIPC apply for LabVIEW {0} ({1}-bit)." -f $MinimumSupportedLVVersion, $SupportedBitness)
