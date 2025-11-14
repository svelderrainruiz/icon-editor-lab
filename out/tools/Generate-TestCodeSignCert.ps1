#Requires -Version 7.0
<#
.SYNOPSIS
  Generate a temporary, self-signed code-signing certificate for local/fork testing.

.DESCRIPTION
  - Creates a self-signed "Code Signing" cert in the current user's store
  - Exports a PFX with a strong random password
  - Emits a Base64 blob for use as an environment secret
  - Optionally writes secrets to secrets.json and/or .env
  - Prints cleanup commands to remove the cert and files

.NOTES
  For TESTING ONLY. Do not use for production/release signing.
#>

[CmdletBinding()]
param(
  [string]$Subject = 'CN=CI Test Signing',
  [int]$DaysValid = 14,
  [string]$OutDir = (Join-Path -Path $PWD -ChildPath 'out\test-codesign'),
  [switch]$EmitJson,
  [switch]$EmitEnv,
  [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $IsWindows) {
  throw "This script requires Windows (uses New-SelfSignedCertificate)."
}

# Ensure output folder
$null = New-Item -ItemType Directory -Force -Path $OutDir

# Create self-signed code-signing cert (exportable key)
$notAfter = (Get-Date).AddDays([Math]::Max(1, $DaysValid))
$cert = New-SelfSignedCertificate `
  -Subject $Subject `
  -Type CodeSigningCert `
  -CertStoreLocation 'Cert:\CurrentUser\My' `
  -NotAfter $notAfter `
  -KeyExportPolicy Exportable `
  -KeyAlgorithm RSA -KeyLength 3072 `
  -HashAlgorithm SHA256

if (-not $cert) { throw "Failed to create self-signed code-signing certificate." }

# Generate a strong random password (Base64 of 48 random bytes)
$pwdPlain = [Convert]::ToBase64String([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(48))
$pwdSecure = ConvertTo-SecureString -String $pwdPlain -AsPlainText -Force

# Export to PFX
$pfxName = "test-codesign-$($cert.Thumbprint.Substring(0,8)).pfx"
$pfxPath = Join-Path $OutDir $pfxName
Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $pwdSecure | Out-Null

# Base64-encode the PFX for easy use as a secret
$b64Path = Join-Path $OutDir "test-codesign.pfx.b64"
[IO.File]::WriteAllBytes($b64Path, [Convert]::FromBase64String(([Convert]::ToBase64String([IO.File]::ReadAllBytes($pfxPath)))))
# Re-read as trimmed string (ensures newline at end when written below)
$pfxB64 = Get-Content -LiteralPath $b64Path -Raw

# Write convenient plain-text files for quick 'gh secret set' usage
$pwdPath = Join-Path $OutDir "WIN_CODESIGN_PFX_PASSWORD.txt"
$b64TxtPath = Join-Path $OutDir "WIN_CODESIGN_PFX_B64.txt"
Set-Content -LiteralPath $pwdPath -Value $pwdPlain -Encoding UTF8 -NoNewline:$false
Set-Content -LiteralPath $b64TxtPath -Value $pfxB64 -Encoding UTF8 -NoNewline:$false

# Optional secret bundles
if ($EmitJson) {
  $jsonPath = Join-Path $OutDir "secrets.json"
  @{ WIN_CODESIGN_PFX_B64 = $pfxB64; WIN_CODESIGN_PFX_PASSWORD = $pwdPlain } |
    ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
}

if ($EmitEnv) {
  $envPath = Join-Path $OutDir "secrets.env"
  @(
    "WIN_CODESIGN_PFX_B64=$pfxB64"
    "WIN_CODESIGN_PFX_PASSWORD=$pwdPlain"
  ) | Set-Content -LiteralPath $envPath -Encoding UTF8
}

if (-not $Quiet) {
  Write-Host ""
  Write-Host "✅ Generated TEST code-signing certificate" -ForegroundColor Green
  Write-Host "  Subject        : $($cert.Subject)"
  Write-Host "  Thumbprint     : $($cert.Thumbprint)"
  Write-Host "  Valid Until    : $($cert.NotAfter.ToString('u'))"
  Write-Host "  PFX            : $pfxPath"
  Write-Host "  B64 (file)     : $b64TxtPath"
  Write-Host "  Password (file): $pwdPath"
  if ($EmitJson) { Write-Host "  JSON           : $jsonPath" }
  if ($EmitEnv)  { Write-Host "  .env           : $envPath" }

  Write-Host ""
  Write-Host "🔐 Secret names to use (match the hardened CI):"
  Write-Host "  - WIN_CODESIGN_PFX_B64"
  Write-Host "  - WIN_CODESIGN_PFX_PASSWORD"

  Write-Host ""
  Write-Host "📦 Examples (run from repo root) — set environment secrets in your fork:"
  Write-Host "  # codesign-dev environment"
  Write-Host "  gh secret set -e codesign-dev WIN_CODESIGN_PFX_B64       -b \"$(Get-Content '$b64TxtPath' -Raw)\""
  Write-Host "  gh secret set -e codesign-dev WIN_CODESIGN_PFX_PASSWORD  -b \"$(Get-Content '$pwdPath'  -Raw)\""
  Write-Host ""
  Write-Host "  # codesign-prod environment (in your fork only, for end-to-end testing)"
  Write-Host "  gh secret set -e codesign-prod WIN_CODESIGN_PFX_B64      -b \"$(Get-Content '$b64TxtPath' -Raw)\""
  Write-Host "  gh secret set -e codesign-prod WIN_CODESIGN_PFX_PASSWORD -b \"$(Get-Content '$pwdPath'  -Raw)\""

  Write-Host ""
  Write-Host "🧹 Cleanup (remove the TEST cert and files when done):"
  Write-Host "  # Remove cert from CurrentUser store"
  Write-Host "  certutil -user -delstore My $($cert.Thumbprint)"
  Write-Host "  # Or (PowerShell): Remove-Item -LiteralPath Cert:\\CurrentUser\\My\\$($cert.Thumbprint) -Force"
  Write-Host "  # Remove files"
  Write-Host "  Remove-Item -LiteralPath '$pfxPath','${b64TxtPath}','${pwdPath}' -Force"
  if ($EmitJson) { Write-Host "  Remove-Item -LiteralPath '$jsonPath' -Force" }
  if ($EmitEnv)  { Write-Host "  Remove-Item -LiteralPath '$envPath'  -Force" }
  Write-Host ""
  Write-Warning "This certificate is for local/test signing ONLY. Do not use it for releases."
}

# Return a small object for programmatic use
[pscustomobject]@{
  Subject   = $cert.Subject
  Thumbprint= $cert.Thumbprint
  PfxPath   = $pfxPath
  PfxBase64 = $pfxB64
  Password  = $pwdPlain
  OutDir    = $OutDir
}

