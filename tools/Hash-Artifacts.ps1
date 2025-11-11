# Hash-Artifacts.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'; $PSModuleAutoLoadingPreference='None'

[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Root,
  [Parameter()][string]$Output = 'checksums.sha256'
)
$rootAbs = Resolve-Path -LiteralPath $Root -ErrorAction Stop
$items = Get-ChildItem -LiteralPath $rootAbs -Recurse -File -ErrorAction Stop
$lines = New-Object System.Collections.Generic.List[string]
foreach ($i in $items) {
  $h = Get-FileHash -LiteralPath $i.FullName -Algorithm SHA256
  $rel = Resolve-Path -LiteralPath $i.FullName | Split-Path -NoQualifier | Resolve-Path -LiteralPath .
  $lines.Add("{0}  {1}" -f $h.Hash.ToLower(), $i.FullName)
}
$pathOut = Join-Path $rootAbs $Output
$lines | Set-Content -LiteralPath $pathOut -Encoding UTF8 -NoNewline:$false
Write-Output "Wrote checksums to $pathOut"
