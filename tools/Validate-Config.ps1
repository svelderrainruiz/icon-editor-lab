Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'; $PSModuleAutoLoadingPreference='None'
. (Join-Path $PSScriptRoot 'Redaction.ps1')
[CmdletBinding()]param(
  [Parameter(Mandatory)][string]$ConfigPath,
  [Parameter()][string]$SchemaPath = (Join-Path $PSScriptRoot '..' 'configs' 'schema' 'vi-diff-heuristics.schema.json')
)
$cfgContent = Get-Content -LiteralPath $ConfigPath -Raw
# Basic JSON validity check
$null = $cfgContent | ConvertFrom-Json -ErrorAction Stop
# Schema validation (if schema exists)
if (Test-Path -LiteralPath $SchemaPath -PathType Leaf) {
  $cfgContent | Test-Json -SchemaFile $SchemaPath -ErrorAction Stop | Out-Null
}
Write-Output "Config validated successfully:" (Resolve-Path -LiteralPath $ConfigPath).Path