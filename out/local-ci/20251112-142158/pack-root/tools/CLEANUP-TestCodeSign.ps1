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
if (-not $IsWindows) { throw "This script requires Windows." }

function Normalize-Thumb([string]$t) {
  if (-not $t) { return $null }
  ($t -replace '\s','').ToUpperInvariant()
}

function Resolve-PfxAndPassword {
  param([string]$OutDir,[string]$PfxPath)
  $pwdPathCandidates = @(
    (Join-Path $OutDir 'WIN_CODESIGN_PFX_PASSWORD.txt')
  )
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

  $pwdFile = $pwdPathCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
  if (-not $pwdFile) { throw "Password file not found in $OutDir (expected WIN_CODESIGN_PFX_PASSWORD.txt)." }

  [pscustomobject]@{
    PfxPath = $pfxFile.FullName
    Password = (Get-Content -LiteralPath $pwdFile -Raw)
  }
}

function Resolve-Thumbprint {
  param([string]$Thumbprint,[string]$OutDir,[string]$PfxPath)
  $t = Normalize-Thumb $Thumbprint
  if ($t) { return $t }

  $p = Resolve-PfxAndPassword -OutDir $OutDir -PfxPath $PfxPath
  if (-not $p) { return $null }

  try {
    $bytes = [IO.File]::ReadAllBytes($p.PfxPath)
    $cert  = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
    $cert.Import($bytes, $p.Password,
      [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet)
    return (Normalize-Thumb $cert.Thumbprint)
  } catch {
    throw "Failed to derive thumbprint from PFX '$($p.PfxPath)': $($_.Exception.Message)"
  }
}

$resolvedThumb = Resolve-Thumbprint -Thumbprint $Thumbprint -OutDir $OutDir -PfxPath $PfxPath
if (-not $resolvedThumb) {
  throw "Could not resolve a certificate thumbprint. Provide -Thumbprint, or ensure $OutDir has a 'test-codesign-*.pfx' and 'WIN_CODESIGN_PFX_PASSWORD.txt'."
}

# --- Remove certificate from CurrentUser\My ---
$certPath = "Cert:\\CurrentUser\\My\\$resolvedThumb"
$removedCert = $false
if (Test-Path -LiteralPath $certPath) {
  if ($PSCmdlet.ShouldProcess("Delete certificate $resolvedThumb from CurrentUser\\My", "Remove-Item $certPath")) {
    try {
      Remove-Item -LiteralPath $certPath -Force
      $removedCert = $true
    } catch {
      # Fallback to certutil
      try {
        & certutil -user -delstore My $resolvedThumb | Out-Null
        $removedCert = $true
      } catch {
        Write-Warning "Failed to delete cert $resolvedThumb from store: $($_.Exception.Message)"
      }
    }
  }
} else {
  Write-Host "No matching cert in CurrentUser\\My (thumbprint $resolvedThumb)."
}

# --- Collect files to delete ---
$files = @()

if ($PfxPath -and (Test-Path -LiteralPath $PfxPath)) {
  $files += (Get-Item -LiteralPath $PfxPath).FullName
} elseif (Test-Path -LiteralPath $OutDir) {
  $files += (Get-ChildItem -LiteralPath $OutDir -Filter 'test-codesign-*.pfx' -File -ErrorAction SilentlyContinue |
             Select-Object -ExpandProperty FullName)
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

# --- Delete files ---
$deleted = New-Object System.Collections.Generic.List[string]
foreach ($f in $files) {
  if ($PSCmdlet.ShouldProcess("Delete file", $f)) {
    try {
      Remove-Item -LiteralPath $f -Force:$Force -ErrorAction Stop
      $deleted.Add($f) | Out-Null
    } catch {
      Write-Warning "Failed to delete $f: $($_.Exception.Message)"
    }
  }
}

# --- Optionally delete env secrets with gh ---
$secretsDeleted = @()
if ($DeleteGhSecrets) {
  if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Warning "gh CLI not found; skipping environment secret deletion."
  } else {
    $names = @('WIN_CODESIGN_PFX_B64','WIN_CODESIGN_PFX_PASSWORD')
    foreach ($envName in $Environments) {
      foreach ($n in $names) {
        if ($PSCmdlet.ShouldProcess("Delete env secret", "$n (env=$envName)")) {
          try {
            $p = Start-Process -FilePath "gh" -ArgumentList @("secret","delete",$n,"--env",$envName,"--yes") `
                               -NoNewWindow -PassThru -Wait
            if ($p.ExitCode -eq 0) { $secretsDeleted += "$envName/$n" }
          } catch {
            Write-Warning "Failed to delete secret $n in env $envName: $($_.Exception.Message)"
          }
        }
      }
    }
  }
}

# --- Summary ---
Write-Host ""
Write-Host "Cleanup summary" -ForegroundColor Cyan
Write-Host ("  Thumbprint removed from store : {0}" -f ($removedCert ? $resolvedThumb : 'not found / not removed'))
if ($deleted.Count -gt 0) {
  Write-Host "  Files deleted:"; $deleted | ForEach-Object { Write-Host "    - $_" }
} else {
  Write-Host "  Files deleted: (none)"
}
if ($DeleteGhSecrets) {
  if ($secretsDeleted.Count -gt 0) {
    Write-Host "  Env secrets deleted:"; $secretsDeleted | ForEach-Object { Write-Host "    - $_" }
  } else {
    Write-Host "  Env secrets deleted: (none)"
  }
}


# SIG # Begin signature block
# MIIFpwYJKoZIhvcNAQcCoIIFmDCCBZQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCC9+YAS6eyMazrc
# OORVNfBB8W9nXf2463upesKl4YoPNKCCAxYwggMSMIIB+qADAgECAhAsVIQg030T
# pkDgjFxn8dadMA0GCSqGSIb3DQEBCwUAMCExHzAdBgNVBAMMFkNJIExvY2FsIHRy
# dXN0ZWQtbG9jYWwwHhcNMjUxMTEyMjIyNjM4WhcNMjUxMTI2MjIzNjM4WjAhMR8w
# HQYDVQQDDBZDSSBMb2NhbCB0cnVzdGVkLWxvY2FsMIIBIjANBgkqhkiG9w0BAQEF
# AAOCAQ8AMIIBCgKCAQEA6DliazVSN8BoTlpL0jcJZBnHhPMfteLJb4Y9nott1Zod
# o34kXqqNTif60bd14uMjAJ4NGoKQRvidNuQSdLReOccP2nJ96CdWQMGfiIbQ0ywN
# 4lhdvfibKy0KZyV4TfeCCZNagvkdtxg06XYg9F8kPGpYVUksFwgVDMnAW/wtuRnk
# mSfhNXhkxxAvYUIfM//dKIZ9ngLRXjoR4SZFcYRWBv1yF5SucOPhThkyypVQ/P8l
# Dgc3xBZpjeReNsdqEDVbUyxnXlFPRR8aQYFg+XhCj3lvxEYFXZQY9HrBYRv3tU/7
# ESC7ohwDcTJh0CYTAH7rWS9efhZSM5xNF7LyR0TDCQIDAQABo0YwRDAOBgNVHQ8B
# Af8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwHQYDVR0OBBYEFIbMHVhvV+uB
# Bpf61CWYRklPIAhKMA0GCSqGSIb3DQEBCwUAA4IBAQBxlITPzL93OzrkfkiseHjk
# Z6KKQBc+h5UiZObsP4PKual3Kz8x6NaLJrP5lCYs37ImRQYwtiEXEBsHyz1xm8Om
# tMlwjCA9hxI29l8pEVbKxxbnUUbHzXtA3UeWZLQ3dIJWtkyKM+izEd2Pd9MSqe6D
# 3/nTDrfuHgF1dCgbJgY+WmPnW+JhiEEr8jhkBwzCLIuTSJeOfo6R8H8dVPmqBBmf
# Yb3UmduuO+EqYIeil5KRhFhAmTlqXSKxw6CSQVnrXzzVwzfmJYfdcWCeyWzHc6T7
# VuRaBTIZz8RgKOjX9zJqWCQra2NWNssXUQ5TulHKyvsprdFFtAdbFkDIe9y0cBuL
# MYIB5zCCAeMCAQEwNTAhMR8wHQYDVQQDDBZDSSBMb2NhbCB0cnVzdGVkLWxvY2Fs
# AhAsVIQg030TpkDgjFxn8dadMA0GCWCGSAFlAwQCAQUAoIGEMBgGCisGAQQBgjcC
# AQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYB
# BAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIHdtx8lNxvdE
# GwQraeAY4Y6icbWBMysq/r8X9ubdHLmOMA0GCSqGSIb3DQEBAQUABIIBAEttZ8eB
# za0f+XwhXdsAyZHwclz5tmEnDf5UnP9qElp2eG9f2Jizp0l615bty2FEIJN7+xvo
# iDaiALDL8LFDRPwxbPfSJ5CszLpHgslaKdEg6FQeuDpMxSJo+1L+eKW7hnmbtkDU
# QHY64No2vOZcl023vkkXq3JRcFV8HXGDMAtf5IQa91ciTp0XeJdpQhle6pDoHkTm
# TKtnFLdNTHWKTtVauYlGDaHdsxX8vcDu7FkK1WMETYRPE+mTynZUqGd8UeFUOBEn
# 1OZqTdnKKMyZY4oChH8/4fQ3+X4EHOCTRT+xVzSLKxY13fi4hWV8QgRCSIQ/o1aj
# uBahzw+p99RyBVk=
# SIG # End signature block
