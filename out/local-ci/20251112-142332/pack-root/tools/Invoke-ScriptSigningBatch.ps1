#Requires -Version 7.0
<#!
.SYNOPSIS
  Signs PowerShell scripts in bulk with optional timestamping and emits progress + summary telemetry.

.DESCRIPTION
  Enumerates *.ps1/*.psm1 files under a target root directory, signs up to MaxFiles using the
  certificate identified by the provided thumbprint, and records aggregate metrics (duration,
  average per-file time, timeout counts). When -UseTimestamp is set, per-file signing is wrapped
  in a background job with a hard timeout to avoid indefinite hangs on flaky RFC-3161 servers.

.PARAMETER Root
  Root directory that contains the script files to sign (e.g., 'unsigned').

.PARAMETER CertificateThumbprint
  Thumbprint of the code-signing certificate already imported into Cert:\CurrentUser\My.

.PARAMETER MaxFiles
  Upper bound on the number of scripts to sign this run. Files are processed in alphabetical order.

.PARAMETER TimeoutSeconds
  Timeout applied to each timestamped signing attempt. Ignored when -UseTimestamp is not supplied.

.PARAMETER UseTimestamp
  Enables RFC-3161 timestamping. If the timestamp attempt times out/fails, the script will retry
  without timestamp and record the fallback in the summary metrics.

.PARAMETER TimestampServer
  RFC-3161 server URL. Defaults to https://timestamp.digicert.com when -UseTimestamp is specified.

.PARAMETER Mode
  Friendly label included in progress + summary output (e.g., 'fork' or 'trusted').

.PARAMETER SummaryPath
  Optional path to append a bullet point (e.g., $env:GITHUB_STEP_SUMMARY) summarizing the signing run.

#>

[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Root,
  [Parameter(Mandatory)][string]$CertificateThumbprint,
  [int]$MaxFiles = 500,
  [int]$TimeoutSeconds = 20,
  [switch]$UseTimestamp,
  [string]$TimestampServer = 'https://timestamp.digicert.com',
  [string]$Mode = 'fork',
  [string]$SummaryPath,
  [switch]$SimulateTimestampFailure
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$rootPath = Resolve-Path -LiteralPath $Root -ErrorAction Stop
$allScripts = Get-ChildItem -LiteralPath $rootPath -Include *.ps1,*.psm1 -Recurse -ErrorAction SilentlyContinue | Sort-Object FullName
if (-not $allScripts) {
  Write-Host "[$Mode] No PowerShell scripts found under '$rootPath'. Nothing to sign."
  return
}

$files = $allScripts | Select-Object -First $MaxFiles
$capHit = ($files.Count -lt $allScripts.Count)
if ($capHit) {
  Write-Warning ("[$Mode] Script list truncated to {0} of {1}. Increase MAX_SIGN_FILES to cover all files." -f $files.Count,$allScripts.Count)
}

$certPath = "Cert:\CurrentUser\My\$CertificateThumbprint"
$cert = Get-ChildItem -LiteralPath $certPath -ErrorAction Stop

function Invoke-SignInline {
  param([string]$Path,[System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate)
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  try {
    Set-AuthenticodeSignature -FilePath $Path -Certificate $Certificate -HashAlgorithm SHA256 | Out-Null
    return @{ status = 'ok'; ms = $sw.ElapsedMilliseconds }
  } catch {
    return @{ status = 'error'; ms = $sw.ElapsedMilliseconds; error = $_.Exception.Message }
  } finally {
    $sw.Stop()
  }
}

function Invoke-SignWithTimestamp {
  param([string]$Path,[string]$Thumb,[string]$TimestampUrl,[int]$TimeoutSec,[switch]$SimulateFailure)
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $sb = {
    param($file,$thumb,$tsa)
    $certLocal = Get-ChildItem "Cert:\CurrentUser\My\$thumb"
    if (-not $certLocal) { throw "Certificate $thumb not found in Cert:\CurrentUser\My" }
    Set-AuthenticodeSignature -FilePath $file -Certificate $certLocal -TimestampServer $tsa -HashAlgorithm SHA256 | Out-Null
  }
  if (Get-Command Start-ThreadJob -ErrorAction SilentlyContinue) {
    $job = Start-ThreadJob -ScriptBlock $sb -ArgumentList $Path,$Thumb,$TimestampUrl
  } else {
    $job = Start-Job -ScriptBlock $sb -ArgumentList $Path,$Thumb,$TimestampUrl
  }
  try {
    if (-not (Wait-Job $job -Timeout $TimeoutSec)) {
      try { Stop-Job $job -Force } catch {}
      try { Receive-Job $job -ErrorAction SilentlyContinue | Out-Null } catch {}
      return @{ status = 'timeout'; ms = $sw.ElapsedMilliseconds }
    }
    try {
      Receive-Job $job -ErrorAction Stop | Out-Null
      $result = @{ status = 'ok'; ms = $sw.ElapsedMilliseconds }
      if ($SimulateFailure) {
        $result.status = 'timeout'
      }
      return $result
    } catch {
      $result = @{ status = 'error'; ms = $sw.ElapsedMilliseconds; error = $_.Exception.Message }
      if ($SimulateFailure) {
        $result.status = 'timeout'
        $result.Remove('error') | Out-Null
      }
      return $result
    }
  } finally {
    $sw.Stop()
    try { Remove-Job $job -Force -ErrorAction SilentlyContinue } catch {}
  }
}

$timeoutUsed = 0
$fallbackUsed = 0
$successMs = 0
$fail = 0
$index = 0
$totalWatch = [System.Diagnostics.Stopwatch]::StartNew()

foreach ($file in $files) {
  $index++
  Write-Host ("[$Mode] [{0}/{1}] Signing {2}" -f $index,$files.Count,$file.FullName)
  if ($UseTimestamp) {
    $tsa = if ([string]::IsNullOrWhiteSpace($TimestampServer)) { 'https://timestamp.digicert.com' } else { $TimestampServer }
    $primary = Invoke-SignWithTimestamp -Path $file.FullName -Thumb $CertificateThumbprint -TimestampUrl $tsa -TimeoutSec $TimeoutSeconds -SimulateFailure:$SimulateTimestampFailure
    switch ($primary.status) {
      'ok'      { Write-Host ("  ✓ ok ({0} ms)" -f $primary.ms); $successMs += $primary.ms }
      'timeout' {
        $timeoutUsed++
        Write-Warning ("  ⏱ TSA timeout after {0} ms; retrying WITHOUT timestamp" -f $primary.ms)
        $secondary = Invoke-SignInline -Path $file.FullName -Certificate $cert
        if ($secondary.status -eq 'ok') {
          $fallbackUsed++
          Write-Host ("  ✓ ok (no timestamp) ({0} ms)" -f $secondary.ms)
          $successMs += $secondary.ms
        } else {
          $fallbackUsed++
          $fail++
          Write-Error "  ✖ failed (no timestamp): $($secondary.error)"
        }
      }
      'error' {
        Write-Warning ("  ⚠ TSA error: {0}; retrying WITHOUT timestamp" -f $primary.error)
        $secondary = Invoke-SignInline -Path $file.FullName -Certificate $cert
        if ($secondary.status -eq 'ok') {
          $fallbackUsed++
          Write-Host ("  ✓ ok (no timestamp) ({0} ms)" -f $secondary.ms)
          $successMs += $secondary.ms
        } else {
          $fallbackUsed++
          $fail++
          Write-Error "  ✖ failed (no timestamp): $($secondary.error)"
        }
      }
    }
  } else {
    $result = Invoke-SignInline -Path $file.FullName -Certificate $cert
    switch ($result.status) {
      'ok'      { Write-Host ("  ✓ ok ({0} ms)" -f $result.ms); $successMs += $result.ms }
      'timeout' { $timeoutUsed++; Write-Warning ("  ⏱ timeout after {0} ms" -f $result.ms); $fail++ }
      'error'   { Write-Warning ("  ⚠ error: {0}" -f $result.error); $fail++ }
    }
  }
}

$totalWatch.Stop()
$completed = $files.Count - $fail
$avgMs = if ($completed -gt 0) { [math]::Round(($successMs / $completed),2) } else { 0 }
$summary = if ($UseTimestamp) {
  "[$Mode] Trusted signing: $completed/$($files.Count) scripts in $([math]::Round($totalWatch.Elapsed.TotalSeconds,2))s (avg ${avgMs} ms, timeouts=$timeoutUsed, fallbacks=$fallbackUsed, cap=$MaxFiles)."
} else {
  "[$Mode] Fork signing: $completed/$($files.Count) scripts in $([math]::Round($totalWatch.Elapsed.TotalSeconds,2))s (avg ${avgMs} ms, timeouts=$timeoutUsed, cap=$MaxFiles)."
}

Write-Host $summary
if ($SummaryPath) {
  try {
    Add-Content -LiteralPath $SummaryPath -Value "- $summary" -ErrorAction Stop
  } catch {
    Write-Warning ("Failed to write summary to {0}: {1}" -f $SummaryPath,$_.Exception.Message)
  }
}

if ($fail -gt 0) {
  throw "$fail script(s) failed to sign."
}

# SIG # Begin signature block
# MIIFpwYJKoZIhvcNAQcCoIIFmDCCBZQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDyfWBjrI09H7kp
# Zvsc4ZQBt/X1mlVKd73Iorr7WUi57qCCAxYwggMSMIIB+qADAgECAhBFacGRfzgn
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
# BAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIMm1Yr6OBcHJ
# 0KipY2BDAt4VYUj201Qo5UKkAn1MjmEJMA0GCSqGSIb3DQEBAQUABIIBAByZNilA
# QcatfcMTwcaPZQ94UwRUxFNFNeZR6NQ+2v87AP3Epct6cCUDGvoGyS6Pivg8f4rt
# sxylB+aG66BNoWqaOGTxEAvFOdLpxnBMFUPrMbXE9J38ozyGjVQLXmUbeUSgVDv6
# 8UmVUON85X0YWtA8six6U7ApOJ08WK6CTOWpBc97HAW4G29RgCFLdx9NSvblPc/F
# owCID8MJ57bI1jTK+Tb2N8rdgu1VuJ+TYbK/ew00nYUbLr4GuFXr/PG4MKDRzwXq
# pb8SJqAhEktP+tq0TZ8oNM5ciqoEMXKI40vg3ukQBL5W8g+1ynUnY0av6mMU0oBk
# xoTvPk38LA67DRo=
# SIG # End signature block
