# Hash-Artifacts.ps1
param(
  [Parameter(Mandatory)][string]$Root,
  [Parameter()][string]$Output = 'checksums.sha256'
)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

$rootAbs = Resolve-Path -LiteralPath $Root -ErrorAction Stop
$rootPath = $rootAbs.ProviderPath
$items = Get-ChildItem -LiteralPath $rootPath -Recurse -File -ErrorAction Stop
$lines = New-Object System.Collections.Generic.List[string]
foreach ($i in $items) {
  $h = Get-FileHash -LiteralPath $i.FullName -Algorithm SHA256
  $relativePath = [System.IO.Path]::GetRelativePath($rootPath, $i.FullName)
  try {
    $lines.Add(("{0}  {1}" -f $h.Hash.ToLower(), $relativePath))
  } catch {
    throw "Failed to format hash entry for '$($i.FullName)' relative '$relativePath': $($_.Exception.Message)"
  }
}
$pathOut = Join-Path $rootPath $Output
$lines | Set-Content -LiteralPath $pathOut -Encoding UTF8 -NoNewline:$false
Write-Output "Wrote checksums to $pathOut"
