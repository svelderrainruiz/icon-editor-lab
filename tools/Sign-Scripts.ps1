# Sign-Scripts.ps1
[CmdletBinding()]
param(
  [Parameter()][string]$Thumbprint,
  [Parameter()][string]$SearchRoot = (Get-Location).Path,
  [Parameter()][string[]]$Include = @("*.ps1","*.psm1"),
  [Parameter()][string[]]$ExcludeDirs = @(".git",".github",".venv","node_modules"),
  [switch]$SkipTimestamp
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'; $PSModuleAutoLoadingPreference='None'
if (-not (Test-Path -LiteralPath $SearchRoot -PathType Container)) {
  throw "Search root not found: $SearchRoot"
}
Write-Host "Signing scripts under: $SearchRoot"
$includeMatchers = @(
  $Include | ForEach-Object {
    if ($_ -and $_.Trim()) {
      [System.Management.Automation.WildcardPattern]::new($_.Trim(),'IgnoreCase')
    }
  }
)
if ($includeMatchers.Count -eq 0) {
  $includeMatchers = @([System.Management.Automation.WildcardPattern]::new('*','IgnoreCase'))
}
function Get-GitTrackedFiles {
  param()
  $gitDir = Join-Path $SearchRoot '.git'
  if (-not (Test-Path -LiteralPath $gitDir -PathType Container)) {
    return @()
  }
  Push-Location $SearchRoot
  try {
    $arguments = @('ls-files','-z','--','*.ps1','*.psm1')
    $output = & git @arguments 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $output) {
      return @()
    }
    return $output -split "`0" | Where-Object { $_ }
  }
  finally {
    Pop-Location
  }
}
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
$gitCandidates = Get-GitTrackedFiles
if ($gitCandidates.Count -gt 0) {
  $candidates = @(
    $gitCandidates | ForEach-Object {
      $path = Join-Path $SearchRoot $_
      if (Test-Path -LiteralPath $path -PathType Leaf) { Get-Item -LiteralPath $path }
    } | Where-Object { $_ }
  )
}
else {
  $candidates = @(Get-ChildItem -LiteralPath $SearchRoot -Recurse -File)
}
Write-Host ("Discovered {0} candidate file(s) before filtering." -f $candidates.Count)
$files = @($candidates | Where-Object {
  $rel = $_.FullName.Substring($SearchRoot.Length).TrimStart('\','/')
  if ($ExcludeDirs | Where-Object { $rel -like ("{0}\*" -f $_) }) {
    return $false
  }
  foreach ($matcher in $includeMatchers) {
    if ($matcher.IsMatch($_.Name)) { return $true }
  }
  return $false
})
foreach ($f in $files) {
  $sig = Get-AuthenticodeSignature -LiteralPath $f.FullName
  if ($sig.Status -ne 'Valid') {
    if ($SkipTimestamp) {
      Write-Verbose ("Signing {0} without timestamp (ephemeral cert)." -f $f.FullName)
      $null = Set-AuthenticodeSignature -LiteralPath $f.FullName -Certificate $cert
    }
    else {
      Write-Verbose ("Signing {0} with timestamp server." -f $f.FullName)
      $null = Set-AuthenticodeSignature -LiteralPath $f.FullName -Certificate $cert -TimestampServer 'http://timestamp.digicert.com'
    }
  }
}
Write-Output "Signed $($files.Count) script(s)."
