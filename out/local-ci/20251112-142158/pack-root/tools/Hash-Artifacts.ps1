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
  $lines.Add("{0}  {1}" -f $h.Hash.ToLower(), $relativePath)
}
$pathOut = Join-Path $rootPath $Output
$lines | Set-Content -LiteralPath $pathOut -Encoding UTF8 -NoNewline:$false
Write-Output "Wrote checksums to $pathOut"

# SIG # Begin signature block
# MIIFpwYJKoZIhvcNAQcCoIIFmDCCBZQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCWfkcSJL0WVvJ3
# LBHfQCxYkPyCm2+QZURIweVTm8c/aqCCAxYwggMSMIIB+qADAgECAhAsVIQg030T
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
# BAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIMPC4YMulz5q
# DjzZZnaVLcrzGqrRUmQ/be7V57c2Qq0wMA0GCSqGSIb3DQEBAQUABIIBAMHu4To+
# mHhy/Wq5LL21GRbhpjRUEaizo/T/xehrTFGl43rEEQ0p6nVuJDDLhoHRJvwJNOD6
# RIOjr/tGbyvvoEqUL7RcFc3jPJWJi5QmPyWwSKZ7+LBv8eoefU4AyKh+igQh4g/F
# ALwuO4B5CRG/Z3FacmBsONrHzZFe2R2tdvoDXbF5uiH2vJmtYgd5WXi+R4MUnYhq
# nHIUtMLAfvPrbxaA7DXSzBHE7jqWsumCwk0t/Vmsp34uUvpIRhCyRxtrRRQKg7Pd
# rem4eHw6f4Pi58D4vMFCSGfiwdkeVjIwvGRO/oyzJdq1zMOdYBLA8rdvDEx2C7bm
# BdIXkRflNmk27rI=
# SIG # End signature block
