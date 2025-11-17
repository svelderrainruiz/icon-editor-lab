#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$MinimumSupportedLVVersion,
    [ValidateSet('32','64')]
    [string]$SupportedBitness = '64',
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$AdditionalArguments
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$message = "[close-labview] Stubbed shutdown for LabVIEW {0} ({1}-bit)" -f `
    ($MinimumSupportedLVVersion ?? 'unknown'), $SupportedBitness
Write-Host $message
$extraArgs = @($AdditionalArguments)
if ($extraArgs.Count -gt 0) {
    Write-Host "[close-labview] Ignoring extra arguments: $($extraArgs -join ', ')"
}
