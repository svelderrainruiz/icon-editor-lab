# Secure-Process.psm1
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'Validate-Paths.ps1')
$ErrorActionPreference='Stop'; $PSModuleAutoLoadingPreference='None'

function Invoke-ProcessSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter()][string[]]$ArgumentList = @(),
        [Parameter()][int]$TimeoutSec = 600,
        [Parameter()][string]$WorkingDirectory = (Get-Location).Path
    )
    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) { throw "FilePath not found: $FilePath" }
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $FilePath
    $psi.WorkingDirectory = (Validate-PathSafe -Path $WorkingDirectory)
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    foreach ($a in $ArgumentList) { $null = $psi.ArgumentList.Add($a) }

    $p = [System.Diagnostics.Process]::new()
    $p.StartInfo = $psi
    if (-not $p.Start()) { throw "Failed to start process: $FilePath" }
    try {
        if (-not $p.WaitForExit($TimeoutSec * 1000)) {
            try { $p.Kill($true) } catch {}
            throw "Process timed out after $TimeoutSec s: $FilePath"
        }
        $stdout = $p.StandardOutput.ReadToEnd()
        $stderr = $p.StandardError.ReadToEnd()
        return [pscustomobject]@{
            ExitCode = $p.ExitCode
            StdOut = $stdout
            StdErr = $stderr
        }
    } finally {
        if (-not $p.HasExited) { try { $p.Kill($true) } catch {} }
        $p.Dispose()
    }
}
Export-ModuleMember -Function Invoke-ProcessSafe

# SIG # Begin signature block
# MIIFpwYJKoZIhvcNAQcCoIIFmDCCBZQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDLM/hZ77J6ko3k
# J1T1SnSI3Zjg9T8EF5sOyyHIvgXLgqCCAxYwggMSMIIB+qADAgECAhBFacGRfzgn
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
# BAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIPEK5pYr/oiP
# 6zXDh72ZtLHO5VLyj1aDMXhTjDbbSs4wMA0GCSqGSIb3DQEBAQUABIIBAKeaO4k+
# J5vLj3kCXKTmA7ymxipu4dX/Hfpub1S9C7JCfixWptUUcKv/Cv1glQQzJW4L0z61
# +yVQ6zpW9jpGZfMnkxOKYssMTpX7Sv/viSVjoZSdHY3CRe7y9PCXFB41V/UCJp3N
# fTd4MRM3XtpVLwfcyEo5uWH07/00FXhr5/VVDv6tkndsmO6jH62jiIMGaWzinRR+
# ss+BEUXakJbCOUeqVpgoIqnfrbPONWrM7RS3f12W2Jjf+QFJ6cVx8gn6Cy4lz6vY
# XWZLya7zMDMvpgZ2vO8MxmRDBRK9VheffQqySOnSieLzMIiT2hxOWymcxL2/IgnZ
# BHFVT+OO5DywMkw=
# SIG # End signature block
