#Requires -Version 7.0
<#
.SYNOPSIS
  Runs fork-mode and trusted-mode signing batches locally to mirror CI behavior.

.DESCRIPTION
  - Prepares SIGN_ROOT by copying repo scripts (tools/, scripts/) plus sample payloads.
  - Generates an ephemeral certificate for each mode and runs Invoke-ScriptSigningBatch.ps1.
  - Prints the summary output so we can compare with GitHub runners.

.PARAMETER SignRoot
  Directory to stage unsigned artifacts. Defaults to 'out'.

.PARAMETER MaxFiles
  Max script count to process (passed through to the batch helper).

.PARAMETER TimeoutSeconds
  Timeout for timestamping; batch helper uses it for per-file waits.
#>

[CmdletBinding()]
param(
  [string]$SignRoot = 'out',
  [int]$MaxFiles = 200,
  [int]$TimeoutSeconds = 20
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Prepare-SignRoot {
  param([string]$Root)
  if (Test-Path $Root) { Remove-Item $Root -Recurse -Force }
  New-Item -ItemType Directory -Path $Root | Out-Null

  $repoRoots = @('tools','scripts')
  foreach ($rr in $repoRoots) {
    $src = Join-Path $PWD $rr
    if (-not (Test-Path $src)) { continue }
    Get-ChildItem -Path $src -Include *.ps1,*.psm1 -Recurse -File |
      ForEach-Object {
        $relative = $_.FullName.Substring($PWD.ToString().Length + 1)
        $dest = Join-Path $Root $relative
        $destDir = Split-Path $dest -Parent
        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
        Copy-Item -Path $_.FullName -Destination $dest -Force
      }
  }

  "Write-Output 'Sample payload for signing test.'" | Set-Content -Path (Join-Path $Root 'Sample-Signed.ps1') -Encoding UTF8
  [IO.File]::WriteAllBytes((Join-Path $Root 'sample.exe'), [byte[]](1..16))
}

function Invoke-SigningMode {
  param(
    [string]$ModeLabel,
    [switch]$UseTimestamp,
    [int]$MaxFiles,
    [int]$TimeoutSeconds
  )
  $cert = New-SelfSignedCertificate -Subject "CN=CI Local $ModeLabel" -Type CodeSigningCert -CertStoreLocation Cert:\CurrentUser\My -NotAfter (Get-Date).AddDays(14)
  $thumb = $cert.Thumbprint
  $args = @(
    '-NoLogo','-NoProfile','-File','tools/Invoke-ScriptSigningBatch.ps1',
    '-Root', $SignRoot,
    '-CertificateThumbprint', $thumb,
    '-MaxFiles', $MaxFiles,
    '-TimeoutSeconds', $TimeoutSeconds,
    '-Mode', $ModeLabel
  )
  if ($UseTimestamp) {
    $args += @('-UseTimestamp','-TimestampServer','https://timestamp.digicert.com')
  }
  Write-Host "`n== Running mode: $ModeLabel ==" -ForegroundColor Cyan
  pwsh @args
}

Prepare-SignRoot -Root $SignRoot
Invoke-SigningMode -ModeLabel 'fork-local' -MaxFiles $MaxFiles -TimeoutSeconds $TimeoutSeconds
Invoke-SigningMode -ModeLabel 'trusted-local' -UseTimestamp -MaxFiles $MaxFiles -TimeoutSeconds $TimeoutSeconds
