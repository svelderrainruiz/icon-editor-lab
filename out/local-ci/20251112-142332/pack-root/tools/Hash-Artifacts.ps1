# Hash-Artifacts.ps1
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Root,
  [Parameter()][string]$Output = 'checksums.sha256'
)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

$rootAbs = Resolve-Path -LiteralPath $Root -ErrorAction Stop
$rootPath = $rootAbs.ProviderPath
$items = Get-ChildItem -LiteralPath $rootPath -Recurse -File -ErrorAction Stop
$lines = New-Object System.Collections.Generic.List[string]
foreach ($i in $items) {
  $h = Get-FileHash -LiteralPath $i.FullName -Algorithm SHA256
  $relativePath = [System.IO.Path]::GetRelativePath($rootPath, $i.FullName)
  try {
    $lines.Add(("{0}  {1}" -f $h.Hash.ToLower(), $relativePath))
  } catch {
    throw "Failed to format hash entry for '$($i.FullName)' relative '$relativePath': $($_.Exception.Message)"
  }
}
$pathOut = Join-Path $rootPath $Output
$lines | Set-Content -LiteralPath $pathOut -Encoding UTF8 -NoNewline:$false
Write-Output "Wrote checksums to $pathOut"

# SIG # Begin signature block
# MIIFpwYJKoZIhvcNAQcCoIIFmDCCBZQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCASG2cZB9SxQNBP
# DwVC9asjKlcJItPjhuWB1EHHmj/2laCCAxYwggMSMIIB+qADAgECAhBFacGRfzgn
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
# BAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIFwh7Ia6nNVg
# FzrXU1zSmX6Kq7zfAQC5vDsMmiqye02wMA0GCSqGSIb3DQEBAQUABIIBABWOwC9y
# EqhElS6tBrcXkt09oW3vo6PeZBLh4ft/wpP23It0bwdc8uy3aARdIgDRLDm6Dl+w
# nImP5Egq1JBk7JPyfh6ZCrdWTldDXrYCbfY5864aPsucmGnexgI7SOtrN0hFzw6X
# 6e6ky2XnKazPFnxyTECW+h426o8epMeFuoT24MPI+4xe1N13QufT3mPjV5L3w9tI
# 4GKPqHU1uKO/IiW6KfUwrJea6P0i6uDerWdLGHKm6ZYhoN3qQu0eAwNGuQ5yRB4Y
# IQEXTUE0DmThcgzFMo6/UgXzF41poWtJBAOXhr9CaHzIf8pPkeABfgN7KiY6uZD7
# ZITUwdrUdnpBh50=
# SIG # End signature block
