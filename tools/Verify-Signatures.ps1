# Verify-Signatures.ps1
[CmdletBinding()]
param(
  [Parameter()][string]$SearchRoot = (Get-Location).Path,
  [Parameter()][string[]]$Include = @("*.ps1","*.psm1"),
  [Parameter()][string[]]$ExcludeDirs = @(".git",".github",".venv","node_modules")
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'; $PSModuleAutoLoadingPreference='None'
$files = Get-ChildItem -LiteralPath $SearchRoot -Recurse -File -Include $Include | Where-Object {
  $rel = $_.FullName.Substring($SearchRoot.Length).TrimStart('\','/')
  -not ($ExcludeDirs | ForEach-Object { $rel -like ("{0}\*" -f $_) })
}
$bad = @()
foreach ($f in $files) {
  $sig = Get-AuthenticodeSignature -LiteralPath $f.FullName
  if ($sig.Status -ne 'Valid') { $bad += [pscustomobject]@{ Path = $f.FullName; Status = $sig.Status } }
}
if ($bad.Count -gt 0) {
  $bad | Format-Table -AutoSize | Out-String | Write-Output
  throw "Signature check failed for $($bad.Count) file(s)."
}
Write-Output "All script signatures are VALID."
