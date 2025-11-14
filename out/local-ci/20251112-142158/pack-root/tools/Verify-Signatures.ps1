# Verify-Signatures.ps1
[CmdletBinding()]
param(
  [Parameter()][string]$SearchRoot = (Get-Location).Path,
  [Parameter()][string[]]$Include = @("*.ps1","*.psm1"),
  [Parameter()][string[]]$ExcludeDirs = @(".git",".github",".venv","node_modules")
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'; $PSModuleAutoLoadingPreference='None'
$files = Get-ChildItem -LiteralPath $SearchRoot -Recurse -File -Include $Include | Where-Object {
  $rel = $_.FullName.Substring($SearchRoot.Length).TrimStart('\','/')
  -not ($ExcludeDirs | ForEach-Object { $rel -like ("{0}\*" -f $_) })
}
$bad = @()
foreach ($f in $files) {
  $sig = Get-AuthenticodeSignature -LiteralPath $f.FullName
  if ($sig.Status -ne 'Valid') { $bad += [pscustomobject]@{ Path = $f.FullName; Status = $sig.Status } }
}
if ($bad.Count -gt 0) {
  $bad | Format-Table -AutoSize | Out-String | Write-Output
  throw "Signature check failed for $($bad.Count) file(s)."
}
Write-Output "All script signatures are VALID."

# SIG # Begin signature block
# MIIFpwYJKoZIhvcNAQcCoIIFmDCCBZQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDA5chJevy6MGSV
# tHJMuyIwbEkqLQdD7aRYKil20DYfiaCCAxYwggMSMIIB+qADAgECAhBFacGRfzgn
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
# BAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIIEZpCeYMGc2
# kHxmC59rnv7kFfu0+1EDOsevLQv84+74MA0GCSqGSIb3DQEBAQUABIIBACpmEpmo
# hO6e7fpbzY3Z3lu05dnMPIp60KLiTwBTPARgjIKQTGSvmyE6TCBKg01v66QnXtPH
# 0xN4mmTy6S68cB6epE6gbqVgKSrRSy0tpDK0/eBdzK7g4leESwPNA7k2VPApPib4
# 3ehUqN/FQ1zw+I61KdrMUz8uod4pPrbkcci5DSt5JkfYvEDwfCs+xV0dk2VJ9Dxu
# nuYDXfcJDhbZSG9hwixq4CrCSRNXkusPSgnWOjFLf4T459KRLzAlxB1xoTD9bxVd
# a04rRZclEN8L/OqwbdE+vGMDUJLyqKbT+p/pNzW8pdB7ROeUWwrlKsasulioAPu8
# yC//MJUP1sct7ZU=
# SIG # End signature block
