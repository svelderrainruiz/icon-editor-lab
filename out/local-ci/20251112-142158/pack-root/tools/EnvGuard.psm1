# EnvGuard.psm1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'; $PSModuleAutoLoadingPreference='None'

function Get-EnvSnapshot {
    [CmdletBinding()]
    param([string[]]$AllowList = @('PATH','TEMP','TMP','HOME','USERPROFILE'))
    $snap = @{}
    foreach ($name in [Environment]::GetEnvironmentVariables().Keys) {
        if ($AllowList -contains $name) { $snap[$name] = [Environment]::GetEnvironmentVariable($name,'Process') }
    }
    return $snap
}

function Set-EnvFromSnapshot {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Snapshot)
    foreach ($k in $Snapshot.Keys) {
        [Environment]::SetEnvironmentVariable($k, [string]$Snapshot[$k], 'Process')
    }
}

Export-ModuleMember -Function Get-EnvSnapshot, Set-EnvFromSnapshot

# SIG # Begin signature block
# MIIFpwYJKoZIhvcNAQcCoIIFmDCCBZQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAzwwfWBljXiDkz
# 9AHE9bg618B2oMEor3Mbt2BkcXsxKKCCAxYwggMSMIIB+qADAgECAhAsVIQg030T
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
# BAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIJlQaYHytxsd
# hJ21/Xd1OOTWhUd4iNiRCRC/DDWxp9vgMA0GCSqGSIb3DQEBAQUABIIBAIJIy+8C
# ILWhtdJKfqAdnl773HAGOE+yW+fnemLXVhlXXKZZ5e/Sqq9+tEcVrPM5WfbZjJRf
# PJjUUgY44aluroqFGaB3wLva/hYbjIzw7302YEntMFthIxuLTuJolm2wbIkKdS5M
# t72MOcm0x98nB48ndK2LgquuZ6w4TpheNrPiCW8nPP20fIw/qNE1Vs6G6I5C6zN2
# vWlHEetnNoSNRr89rcKI2vnDIgR5oZyftdGkMVH4PrNolqDIrBZ9a3c6ha28nYfC
# upybmkWEo+nnIrIwirgEieH+J8mWokrmS1tYinNc6nPVZEsSyXSMoHjpTZfOCpdH
# ACbuhBKVag6XJuY=
# SIG # End signature block
