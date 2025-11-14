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
# OORVNfBB8W9nXf2463upesKl4YoPNKCCAxYwggMSMIIB+qADAgECAhBFacGRfzgn
# gUtTZCA6xb2UMA0GCSqGSIb3DQEBCwUAMCExHzAdBgNVBAMMFkNJIExvY2FsIHRy
# dXN0ZWQtbG9jYWwwHhcNMjUxMTEyMjIyMzQ0WhcNMjUxMTI2MjIzMzQ0WjAhMR8w
# HQYDVQQDDBZDSSBMb2NhbCB0cnVzdGVkLWxvY2FsMIIBIjANBgkqhkiG9w0BAQEF
# AAOCAQ8AMIIBCgKCAQEArLIjypldbQa6j3OINQ2E9x22V/m3qA8mMqBSZDGgPVYi
# mbtb3BkHNgTdNBUNc/j/b9S4ftW9Wghg7vttF7XylXlr0bdUrc6X7QA5K0wNRUYH
# DbS8ZB94wd7yL875jDqeHDtQxtFGP0rjCbpvI1avmOF4fLRrvu3X6GO+lkKL6IYZ
# XALKku/CNMFQ5DknCZl2X/S3aOoVRhk8zJ4Q0E/92ZSGZpAT6hFOvD97T91JkND3
# mMSk8d7px2dPMCQ6xPsxeRWZcpvRPgoRZF6LgNXwLcCQ9amgMHoQxaeaDUzfkfZm
# 3QStrTPUEfFbkFOHHhPcxJ/9PzijbEx7wNhJvRknkQIDAQABo0YwRDAOBgNVHQ8B
# Af8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwHQYDVR0OBBYEFCKgY06putCk
# kHwiQyeGIt5iDHBMMA0GCSqGSIb3DQEBCwUAA4IBAQClG9rOUrOnsxL10jqrcaHa
# HORh6canTRSWTazw9sCNeas9aqp+qpHDYayN+y99y1diP/eaMhvOnHjPTftL2LlY
# qqAMCPg2MXLmxifLWGgy/Sv4RbJv9YtAGXodjnVvNvas0eGPq3stk8LFkaYB/gf2
# xWjsimNW6MMLEDHmkzHznwcrmOD8eUTOlVjRrUUi4/bi2/9/ff6wX9Gus3DHAV9q
# JE48SEkFu7km1bgpFq9rxxGgWAOU0WjSIxIVHbKgURyujCNsUmO9GsIYTDe065TG
# 82y+b2jJmBiRWKIPrdiKzGi2aZArUaNQ7dcS10XpD/p+nyc6i3bu0vLfgRUXL59j
# MYIB5zCCAeMCAQEwNTAhMR8wHQYDVQQDDBZDSSBMb2NhbCB0cnVzdGVkLWxvY2Fs
# AhBFacGRfzgngUtTZCA6xb2UMA0GCWCGSAFlAwQCAQUAoIGEMBgGCisGAQQBgjcC
# AQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYB
# BAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIHdtx8lNxvdE
# GwQraeAY4Y6icbWBMysq/r8X9ubdHLmOMA0GCSqGSIb3DQEBAQUABIIBAFsopgGt
# 3nUfIwok2ozm58QQPEbkwnHu3qLhWLKlUdc+RZTAgekRDq+tvRVds3R8Vj9As1Jn
# 0KYzZW9oGG45nJb+s5so53m3Wie+418PtXNSxdgfyRBjVng2r/sVkQeaQ/labW9c
# d2HqI8Zmh99Lyf+y0B9ZIvgGqhDwwzTkMndEW0EKVWtL3b2pNAIyuGsvxRTnX+eI
# LWrvlv3lwe02ZhbG+7mWXHIsCwEo4m9H2u/tjwOXhTgovvD8Ma3ssxsIiV7UVzaX
# XM8vz1T0Bzc6grOlGrjbLo9AtLM80ImVNTNqM2bHz5xKHs3AlIOMqp+7xwv8/u7S
# ozo1dJ9isdeuTiE=
# SIG # End signature block
