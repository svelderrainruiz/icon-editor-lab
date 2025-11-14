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
# 9AHE9bg618B2oMEor3Mbt2BkcXsxKKCCAxYwggMSMIIB+qADAgECAhBFacGRfzgn
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
# BAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIJlQaYHytxsd
# hJ21/Xd1OOTWhUd4iNiRCRC/DDWxp9vgMA0GCSqGSIb3DQEBAQUABIIBAGOBWLXM
# I3Gc/WHNTrRATbZxJ6RQvUeiDF6e3V5Rv3LxCivfb65dnOWVmQ2CrWGEmWQtdbXw
# xEC3+hcz/B1Ds1hZKaBvnQ7lyUZYG+ttS8wRazyiJzYIhfdgj4zdrp3gCuYLlLtY
# E/x4YUONJfLKeNyZFMlrgWEza64v4Ui4FwIn5jv1WQ8iko2rTwfdyDwLI42d9gs4
# RjxDCEb51wG9SO5e5UGf0ndhzvsAaO4l/VWYYCfevo5q8q3rt3Al7EBZl7NmaTiV
# C1JVoVBUAK2rYe0TQisRS1KID8Pw9FwPfYfp+5IUxIzwPl97h4bbevI3kdst+kXP
# 6htG0JLVMdrbUH0=
# SIG # End signature block
