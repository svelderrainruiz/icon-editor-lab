# tools/CLEANUP-TestCodeSign.ps1
#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param(
  [string]$Thumbprint,
  [string]$OutDir = (Join-Path -Path $PWD -ChildPath 'out\test-codesign'),
  [string]$PfxPath,
  [switch]$DeleteGhSecrets,
  [string[]]$Environments = @('codesign-dev','codesign-prod'),
  [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'This script requires Windows.' }

function Normalize-Thumb([string]$t) {
  if (-not $t) { return $null }
  ($t -replace '\s','').ToUpperInvariant()
}

function Resolve-PfxAndPassword {
  param([string]$OutDir,[string]$PfxPath)
  $pwdFile = Join-Path $OutDir 'WIN_CODESIGN_PFX_PASSWORD.txt'
  $pfxFile = $null
  if ($PfxPath) {
    if (-not (Test-Path -LiteralPath $PfxPath)) { throw "Specified PFX not found: $PfxPath" }
    $pfxFile = Get-Item -LiteralPath $PfxPath
  } else {
    if (-not (Test-Path -LiteralPath $OutDir)) { return $null }
    $pfxFile = Get-ChildItem -LiteralPath $OutDir -Filter 'test-codesign-*.pfx' -File -ErrorAction SilentlyContinue |
               Sort-Object LastWriteTime -Descending | Select-Object -First 1
  }
  if (-not $pfxFile) { return $null }
  if (-not (Test-Path -LiteralPath $pwdFile)) { throw "Password file not found in $OutDir (WIN_CODESIGN_PFX_PASSWORD.txt)." }
  [pscustomobject]@{ PfxPath = $pfxFile.FullName; Password = (Get-Content -LiteralPath $pwdFile -Raw) }
}

function Resolve-Thumbprint {
  param([string]$Thumbprint,[string]$OutDir,[string]$PfxPath)
  $t = Normalize-Thumb $Thumbprint
  if ($t) { return $t }
  $p = Resolve-PfxAndPassword -OutDir $OutDir -PfxPath $PfxPath
  if (-not $p) { return $null }
  $bytes = [IO.File]::ReadAllBytes($p.PfxPath)
  $cert  = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
  $cert.Import($bytes, $p.Password, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet)
  return (Normalize-Thumb $cert.Thumbprint)
}

$resolvedThumb = Resolve-Thumbprint -Thumbprint $Thumbprint -OutDir $OutDir -PfxPath $PfxPath
if (-not $resolvedThumb) { throw "Could not resolve a certificate thumbprint. Provide -Thumbprint or ensure $OutDir has the generated PFX/password." }

$certPath = "Cert:\\CurrentUser\\My\\$resolvedThumb"
$removedCert = $false
if (Test-Path -LiteralPath $certPath) {
  if ($PSCmdlet.ShouldProcess("Delete certificate $resolvedThumb", "Remove-Item $certPath")) {
    try {
      Remove-Item -LiteralPath $certPath -Force
      $removedCert = $true
    } catch {
      try { & certutil -user -delstore My $resolvedThumb | Out-Null; $removedCert = $true } catch {}
    }
  }
}

$files = @()
if ($PfxPath -and (Test-Path -LiteralPath $PfxPath)) {
  $files += (Get-Item -LiteralPath $PfxPath).FullName
} elseif (Test-Path -LiteralPath $OutDir) {
  $files += (Get-ChildItem -LiteralPath $OutDir -Filter 'test-codesign-*.pfx' -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
}
$sidecars = @(
  (Join-Path $OutDir 'WIN_CODESIGN_PFX_B64.txt'),
  (Join-Path $OutDir 'WIN_CODESIGN_PFX_PASSWORD.txt'),
  (Join-Path $OutDir 'test-codesign.pfx.b64'),
  (Join-Path $OutDir 'secrets.json'),
  (Join-Path $OutDir 'secrets.env')
)
$files += ($sidecars | Where-Object { Test-Path -LiteralPath $_ })
$files = $files | Select-Object -Unique

$deleted = New-Object System.Collections.Generic.List[string]
foreach ($f in $files) {
  if ($PSCmdlet.ShouldProcess('Delete file', $f)) {
    try { Remove-Item -LiteralPath $f -Force:$Force -ErrorAction Stop; $deleted.Add($f) | Out-Null } catch {}
  }
}

$secretsDeleted = @()
if ($DeleteGhSecrets) {
  if (Get-Command gh -ErrorAction SilentlyContinue) {
    $names = @('WIN_CODESIGN_PFX_B64','WIN_CODESIGN_PFX_PASSWORD')
    foreach ($envName in $Environments) {
      foreach ($n in $names) {
        if ($PSCmdlet.ShouldProcess('Delete env secret', "$n (env=$envName)")) {
          try { gh secret delete $n --env $envName --yes | Out-Null; $secretsDeleted += "$envName/$n" } catch {}
        }
      }
    }
  }
}

Write-Host ''
Write-Host 'Cleanup summary' -ForegroundColor Cyan
Write-Host ("  Thumbprint removed from store : {0}" -f ($removedCert ? $resolvedThumb : 'not found / not removed'))
if ($deleted.Count -gt 0) { Write-Host '  Files deleted:'; $deleted | ForEach-Object { Write-Host "    - $_" } } else { Write-Host '  Files deleted: (none)' }
if ($DeleteGhSecrets) { if ($secretsDeleted.Count -gt 0) { Write-Host '  Env secrets deleted:'; $secretsDeleted | ForEach-Object { Write-Host "    - $_" } } else { Write-Host '  Env secrets deleted: (none)' } }

