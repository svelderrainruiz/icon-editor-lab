[CmdletBinding()]
param(
  [string]$Root = (Resolve-Path "$PSScriptRoot").Path
)
$ErrorActionPreference = 'Stop'
Write-Host "Self-check: parsing *.ps1/*.psm1 under $Root"
$files = Get-ChildItem -Path $Root -Recurse -Include *.ps1,*.psm1 -File -ErrorAction SilentlyContinue
$errors = @()
foreach ($f in $files) {
  [System.Management.Automation.Language.Token[]]$t = $null
  [System.Management.Automation.Language.ParseError[]]$e = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$t, [ref]$e)
  if ($e.Count -gt 0) {
    $errors += [PSCustomObject]@{ Path = $f.FullName; Message = $e[0].Message }
  }
}
if ($errors) {
  $errors | ForEach-Object { Write-Error ("Parse error in {0}: {1}" -f $_.Path, $_.Message) }
  exit 1
}
Write-Host "OK: $($files.Count) files parsed without errors."
