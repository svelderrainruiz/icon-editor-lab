#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CurrentFilename,
    [Parameter(Mandatory = $true)]
    [string]$NewFilename
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$resolvedSource = (Resolve-Path -LiteralPath $CurrentFilename -ErrorAction Stop).ProviderPath
$destinationDir = Split-Path -Parent $NewFilename
if ($destinationDir -and -not (Test-Path -LiteralPath $destinationDir -PathType Container)) {
    New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
}

Move-Item -LiteralPath $resolvedSource -Destination $NewFilename -Force
Write-Host ("[rename-file] Renamed '{0}' to '{1}'" -f $resolvedSource, $NewFilename)
