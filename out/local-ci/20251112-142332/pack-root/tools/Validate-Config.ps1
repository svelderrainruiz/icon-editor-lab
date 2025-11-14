[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$ConfigPath,
  [Parameter()][string]$SchemaPath = (Join-Path $PSScriptRoot '..' 'configs' 'schema' 'vi-diff-heuristics.schema.json')
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'; $PSModuleAutoLoadingPreference='None'
. (Join-Path $PSScriptRoot 'Redaction.ps1')
$cfgContent = Get-Content -LiteralPath $ConfigPath -Raw
# Basic JSON validity check
$null = $cfgContent | ConvertFrom-Json -ErrorAction Stop
# Schema validation (if schema exists)
if (Test-Path -LiteralPath $SchemaPath -PathType Leaf) {
  $cfgContent | Test-Json -SchemaFile $SchemaPath -ErrorAction Stop | Out-Null
}
Write-Output "Config validated successfully:" (Resolve-Path -LiteralPath $ConfigPath).Path

# SIG # Begin signature block
# MIIFpwYJKoZIhvcNAQcCoIIFmDCCBZQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAtM1F8YzQ4xa9F
# 7QuDGJd4jTwMhZsuR+3nhXLiXLTUlKCCAxYwggMSMIIB+qADAgECAhBFacGRfzgn
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
# BAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIPGNlwZgDGGO
# 4eoZqf6qFtcbYyZe5LvdTuTwGIaPVsX8MA0GCSqGSIb3DQEBAQUABIIBAFqhXlCk
# Q4tv/HsDM526S3c0NHDe8zhK6IzKDq46OYj6QRYM3wK03mSkewQqfVlGtdF78xyV
# 5ETXrwTKP+QQY3+VBXZ8leTgHnyFQZCBEJggja5uttVjo2AKKVYdEc9f0TJOrGX3
# nZJEfZyJlOYC1tMgAPRo5fMooZipmQopoeXfbVTAA4sVCnLy6BRPzDcvnEOIFQUr
# +ZQzVlDVbvbuEmfT+X0bwI35OM3PQHRqXOCyVJFcPePpITuUUgGbVNuKEY8wrHD1
# OcbfgOOyoecw3j+1FCqTCFw1ao9bJCPmBI8C+6DyM0E+NPbslQ8Iis9b+TuJCGps
# D0x2s4YGGr2RraE=
# SIG # End signature block
