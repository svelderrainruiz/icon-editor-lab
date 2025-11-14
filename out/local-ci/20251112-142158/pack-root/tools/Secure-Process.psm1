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
# J1T1SnSI3Zjg9T8EF5sOyyHIvgXLgqCCAxYwggMSMIIB+qADAgECAhAsVIQg030T
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
# BAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIPEK5pYr/oiP
# 6zXDh72ZtLHO5VLyj1aDMXhTjDbbSs4wMA0GCSqGSIb3DQEBAQUABIIBAE/jf0jf
# aKgSWUVTag5l736FFX+VIX7/j3LoFj1Fb63qCFZ5W/KMxKvI4EEogwXCrJyev4gZ
# u4XRBzPaEeX3boefGaz+ZBofkNIiMIeB2Xx2QCYOIAhdxrDiNXN+lZ7H9+j+lJpq
# g8QWnsEMyCPaLQDeeErN0D3XjxuJLq1BoYmERwTfOsK3vCuiqhdJvz8leNwVHgNE
# bRdHMYzssscmAPeHGSjYjgjhQhOOk1PhgMwhfOsbZByHUiKK1PMDuRdCJ6k+9sxz
# 8X8f8gxqV9gOu8qgykeaLfOZ4VwCmgni8CqnQeTY4OyBRZ0VJ4hE1GA3c9UC+Jfh
# dg53rLVv2G4qju8=
# SIG # End signature block
