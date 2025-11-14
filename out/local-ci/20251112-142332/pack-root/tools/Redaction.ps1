# Redaction.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'; $PSModuleAutoLoadingPreference='None'

function Write-LogSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [Parameter()][ValidateSet('INFO','WARN','ERROR')][string]$Level = 'INFO'
    )
    # Redact common secret/token patterns (simple heuristic)
    $msg = $Message -replace '([A-Za-z0-9-_]{20,})','****' `
                    -replace '(?i)(secret|token|password)\s*[:=]\s*[^ \t\r\n]+','$1=****'
    $ts = (Get-Date).ToString('s')
    Write-Output "[$ts][$Level] $msg"
}
if ($ExecutionContext.SessionState.Module) {
    Export-ModuleMember -Function Write-LogSafe
}

# SIG # Begin signature block
# MIIFpwYJKoZIhvcNAQcCoIIFmDCCBZQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB5QE8/zfwZTTR5
# g9if2C7NwESBApxi1XkQIcw6fBWi3aCCAxYwggMSMIIB+qADAgECAhBFacGRfzgn
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
# BAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIEfHLCIlw9Py
# EI3fUHQlFhw4tq7Q+oRZQIlIetQ/aFBMMA0GCSqGSIb3DQEBAQUABIIBAH2OASwn
# x+OU8cLTi1TB4vzM5oAPoEw2thmH/Kq9hqLC10Mq7LIB1HXLhNO13ztrGG4C3t+b
# GewfNQwiCH2y3xsktd7k9lzRfBtSTKXv3wZLACHi1i98weDESo2MOU7dseQ0NB22
# g7CFwtPl08+hBDIBwJ/RGps6qTOSvXkJEdpA5uko3uMCqCNEmekQjPtAPmbG6JCy
# Z9dG7nC7mnFR2JUHDo9qlpQ2UR3FWRgY96towmK41z4HDBTt2UGQyO2MBSPnyM2a
# 2JMz9RRbk27pCAqgkx+WQ9OWIJzshJnFafut6xCcO8cfkBqn6LUZBjoIozEGv4zc
# efRp5raL6GCNzpY=
# SIG # End signature block
