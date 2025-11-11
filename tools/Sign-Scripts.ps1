# Sign-Scripts.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'; $PSModuleAutoLoadingPreference='None'
[CmdletBinding()]
param(
  [Parameter()][string]$Thumbprint,
  [Parameter()][string]$SearchRoot = (Get-Location).Path,
  [Parameter()][string[]]$Include = @("*.ps1","*.psm1"),
  [Parameter()][string[]]$ExcludeDirs = @(".git",".github",".venv","node_modules")
)
function Get-CodeSigningCert {
  param([string]$Thumbprint)
  if ($Thumbprint) {
    $c = Get-ChildItem Cert:\CurrentUser\My\$Thumbprint -ErrorAction SilentlyContinue
    if ($c) { return $c }
  }
  $c = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.HasPrivateKey -and $_.EnhancedKeyUsageList.FriendlyName -contains 'Code Signing' } | Select-Object -First 1
  if (-not $c) { throw 'No suitable code-signing certificate found.' }
  return $c
}
$cert = Get-CodeSigningCert -Thumbprint $Thumbprint
$files = Get-ChildItem -LiteralPath $SearchRoot -Recurse -File -Include $Include | Where-Object {
  $rel = $_.FullName.Substring($SearchRoot.Length).TrimStart('\','/')
  -not ($ExcludeDirs | ForEach-Object { $rel -like ("{0}\*" -f $_) })
}
foreach ($f in $files) {
  $sig = Get-AuthenticodeSignature -LiteralPath $f.FullName
  if ($sig.Status -ne 'Valid') {
    $null = Set-AuthenticodeSignature -LiteralPath $f.FullName -Certificate $cert -TimestampServer 'http://timestamp.digicert.com'
  }
}
Write-Output "Signed $($files.Count) script(s)."
