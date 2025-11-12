# tools/Generate-TestCodeSignCert.ps1
#Requires -Version 7.0
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

if (-not $IsWindows) { throw 'This script requires Windows (uses New-SelfSignedCertificate).' }

if (-not (Test-Path -LiteralPath $OutDir -PathType Container)) {
  $null = New-Item -ItemType Directory -Force -Path $OutDir
}

$notAfter = (Get-Date).AddDays([Math]::Max(1, $DaysValid))
$cert = New-SelfSignedCertificate `
  -Subject $Subject `
  -Type CodeSigningCert `
  -CertStoreLocation 'Cert:\CurrentUser\My' `
  -NotAfter $notAfter `
  -KeyExportPolicy Exportable `
  -KeyAlgorithm RSA -KeyLength 3072 `
  -HashAlgorithm SHA256
if (-not $cert) { throw 'Failed to create self-signed code-signing certificate.' }

$pwdPlain = [Convert]::ToBase64String([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(48))
$pwdSecure = ConvertTo-SecureString -String $pwdPlain -AsPlainText -Force

$pfxName = "test-codesign-$($cert.Thumbprint.Substring(0,8)).pfx"
$pfxPath = Join-Path $OutDir $pfxName
Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $pwdSecure | Out-Null

$pfxBytes = [IO.File]::ReadAllBytes($pfxPath)
$pfxB64 = [Convert]::ToBase64String($pfxBytes)

$pwdPath = Join-Path $OutDir 'WIN_CODESIGN_PFX_PASSWORD.txt'
$b64TxtPath = Join-Path $OutDir 'WIN_CODESIGN_PFX_B64.txt'
Set-Content -LiteralPath $pwdPath -Value $pwdPlain -Encoding UTF8
Set-Content -LiteralPath $b64TxtPath -Value $pfxB64 -Encoding UTF8

if ($EmitJson) {
  $jsonPath = Join-Path $OutDir 'secrets.json'
  @{ WIN_CODESIGN_PFX_B64 = $pfxB64; WIN_CODESIGN_PFX_PASSWORD = $pwdPlain } |
    ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
}
if ($EmitEnv) {
  $envPath = Join-Path $OutDir 'secrets.env'
  @(
    "WIN_CODESIGN_PFX_B64=$pfxB64"
    "WIN_CODESIGN_PFX_PASSWORD=$pwdPlain"
  ) | Set-Content -LiteralPath $envPath -Encoding UTF8
}

if (-not $Quiet) {
  Write-Host ''
  Write-Host 'Generated TEST code-signing certificate' -ForegroundColor Green
  Write-Host "  Subject        : $($cert.Subject)"
  Write-Host "  Thumbprint     : $($cert.Thumbprint)"
  Write-Host "  Valid Until    : $($cert.NotAfter.ToString('u'))"
  Write-Host "  PFX            : $pfxPath"
  Write-Host "  B64 (file)     : $b64TxtPath"
  Write-Host "  Password (file): $pwdPath"
  if ($EmitJson) { Write-Host "  JSON           : $jsonPath" }
  if ($EmitEnv)  { Write-Host "  .env           : $envPath" }

  Write-Host ''
  Write-Host 'Secret names to use:'
  Write-Host '  - WIN_CODESIGN_PFX_B64'
  Write-Host '  - WIN_CODESIGN_PFX_PASSWORD'

  Write-Host ''
  Write-Host 'Examples (run from repo root):'
  Write-Host "  gh secret set -e codesign-dev  WIN_CODESIGN_PFX_B64      -b \"$(Get-Content '$b64TxtPath' -Raw)\""
  Write-Host "  gh secret set -e codesign-dev  WIN_CODESIGN_PFX_PASSWORD -b \"$(Get-Content '$pwdPath'  -Raw)\""
  Write-Host "  gh secret set -e codesign-prod WIN_CODESIGN_PFX_B64      -b \"$(Get-Content '$b64TxtPath' -Raw)\""
  Write-Host "  gh secret set -e codesign-prod WIN_CODESIGN_PFX_PASSWORD -b \"$(Get-Content '$pwdPath'  -Raw)\""

  Write-Host ''
  Write-Host 'Cleanup (remove cert and files when done):'
  Write-Host "  certutil -user -delstore My $($cert.Thumbprint)"
  Write-Host "  Remove-Item -LiteralPath '$pfxPath','${b64TxtPath}','${pwdPath}' -Force"
  Write-Warning 'This certificate is for local/test signing ONLY. Do not use it for releases.'
}

[pscustomobject]@{
  Subject    = $cert.Subject
  Thumbprint = $cert.Thumbprint
  PfxPath    = $pfxPath
  PfxBase64  = $pfxB64
  Password   = $pwdPlain
  OutDir     = $OutDir
}

