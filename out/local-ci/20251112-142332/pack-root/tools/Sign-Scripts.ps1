# Sign-Scripts.ps1
[CmdletBinding()]
param(
  [Parameter()][string]$Thumbprint,
  [Parameter()][string]$SearchRoot = (Get-Location).Path,
  [Parameter()][string[]]$Include = @("*.ps1","*.psm1"),
  [Parameter()][string[]]$ExcludeDirs = @(".git",".github",".venv","node_modules"),
  [switch]$SkipTimestamp,
  [Parameter()][ValidateRange(1,1000)][int]$ProgressInterval = 25,
  [Parameter()][ValidateRange(0,1000)][int]$ThrottleMilliseconds = 0
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
  Write-Host ("Discovered {0} git-tracked candidate(s) via ls-files." -f $gitCandidates.Count)
  $candidates = @(
    $gitCandidates | ForEach-Object {
      $path = Join-Path $SearchRoot $_
      if (Test-Path -LiteralPath $path -PathType Leaf) { Get-Item -LiteralPath $path }
    } | Where-Object { $_ }
  )
}
else {
  Write-Host 'git ls-files returned no matches; falling back to filesystem enumeration.'
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
$total = $files.Count
if ($total -eq 0) {
  Write-Warning 'No files matched the signing criteria; nothing to do.'
  return
}
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$processed = 0
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
  $processed++
  $logCheckpoint = ($ProgressInterval -gt 0) -and (($processed -eq 1) -or ($processed % $ProgressInterval -eq 0) -or ($processed -eq $total))
  if ($logCheckpoint) {
    Write-Host ("[{0}/{1}] Last signed: {2}" -f $processed, $total, $f.FullName)
  }
  if ($ThrottleMilliseconds -gt 0) {
    Start-Sleep -Milliseconds $ThrottleMilliseconds
  }
}
$stopwatch.Stop()
Write-Output ("Signed {0} script(s) in {1:n2}s." -f $processed, $stopwatch.Elapsed.TotalSeconds)

# SIG # Begin signature block
# MIIFpwYJKoZIhvcNAQcCoIIFmDCCBZQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDYpfv9H/2BrGi3
# 0MwBmTlEqdu/5KsCsUUBa2BGGZtVxKCCAxYwggMSMIIB+qADAgECAhBFacGRfzgn
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
# BAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIBiG+2ADMClH
# s6Yi2OyfzhR1yY57aD5XUqXcEBcdbcrjMA0GCSqGSIb3DQEBAQUABIIBAGvGrh2U
# g80MvN63zjki6RzIB8sZgxzMA0SFAPESLZ5fcqjXQX/EP4ljLNqhJ4GqgVg9TlIv
# rRbkoTclttrjMyfukeIeRgX+pJ1GFZwjYxcbE8Jk8NusfAkvukkpH2RAVDSJOflV
# dbR5r4BEy71MQds3R3l9O2qn+2wDck6YAfcxoeuUCfOsYUP9QuqCK+ttdi5MBm5J
# RI/MfEJHCZU7qBd0NGRMpkWj3AQGQD5SLXehks6gEo8L6sO+l7aH8IAHYXJpiqSh
# 5nI4wNe6iUyyMCZXA/fzATjg0lc9DHOd53LWunEswGjvuG/j/kcoIioIsnXr4N3H
# FeOX7Ir6CUOnw88=
# SIG # End signature block
