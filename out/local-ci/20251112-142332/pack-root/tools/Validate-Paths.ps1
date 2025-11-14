# Validate-Paths.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'; $PSModuleAutoLoadingPreference='None'

function Test-PathSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter()][switch]$RequireAbsolute
    )
    if ($Path -match '[;&|`]' -or $Path -match '\.\.') { return $false }
    try {
        $rp = Resolve-Path -LiteralPath $Path -ErrorAction Stop
        if ($RequireAbsolute -and -not ($rp.Path -match '^(?:[A-Za-z]:[\\/]|/)')) { return $false }
        return $true
    } catch { return $false }
}

function Validate-PathSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter()][switch]$RequireAbsolute
    )
    if (-not (Test-PathSafe -Path $Path -RequireAbsolute:$RequireAbsolute)) {
        throw "Unsafe or invalid path: $Path"
    }
    return (Resolve-Path -LiteralPath $Path).Path
}

Export-ModuleMember -Function Test-PathSafe, Validate-PathSafe

# SIG # Begin signature block
# MIIFpwYJKoZIhvcNAQcCoIIFmDCCBZQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBRKRGFgRiwJrUW
# ser+RbKUtmM3v2Ar6IG3lNNJMXHBxaCCAxYwggMSMIIB+qADAgECAhBFacGRfzgn
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
# BAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEINpvsU+HHb6K
# gYnFC+DOD7Pi21ghNNfHTvYHF7x5UIBMMA0GCSqGSIb3DQEBAQUABIIBAIF01rdq
# fLMrxM7HAS4aS4DT7MuQYNySswyaO2KcIzdPeBXzttMqpNSatxFXLWvebMVMfh9D
# RTrvumj4e6kCAb+C305w1sP+vaWDtBaTtMQ8Pqo3paJa2rGam2JPfEBgTUs4xn7S
# sc76OI9yL865L8dGpEl0szmwxuCx6YQXkkgttsiRFgNxJEBbtDPS5FOhkZSzOkJL
# NCAkF0w2QzEb+aKhSa0cSYSfgK7OK+xpz0ca/Jp/aZ4rYIf1RNw2HpfZB4MVjZml
# 5QfFPEae1koAP3fYW1vl8KL6wGwL9d8REBKEuJsSOWMB3l1C45G7HJsJP4Fakg7b
# tOYS/6nk3FrIL2I=
# SIG # End signature block
