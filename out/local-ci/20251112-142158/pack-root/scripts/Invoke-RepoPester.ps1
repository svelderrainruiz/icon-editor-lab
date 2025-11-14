#Requires -Version 7.0
<#
.SYNOPSIS
  Consistent entry point for running the repository's Pester suite.

.DESCRIPTION
  Loads tests/Pester.runsettings.psd1, applies optional tag/exclude filters,
  and runs Invoke-Pester. When -CI is specified, writes JUnit output under
  out/test-results/pester.xml (creating the folder if needed).

.PARAMETER Tag
  Only run tests tagged with any of the specified values.

.PARAMETER ExcludeTag
  Skip tests tagged with any of the specified values.

.PARAMETER CI
  Enables JUnit output to out/test-results/pester.xml.
#>

[CmdletBinding()]
param(
  [string[]]$Tag,
  [string[]]$ExcludeTag,
  [switch]$CI
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$configPath = Join-Path $repoRoot 'tests' 'Pester.runsettings.psd1'
if (-not (Test-Path $configPath)) {
  throw "Pester configuration not found: $configPath"
}

$config = Import-PowerShellDataFile -LiteralPath $configPath

# Normalize relative paths based on repo root
$config.Run.Path = @(
  $config.Run.Path | ForEach-Object {
    (Resolve-Path (Join-Path $repoRoot $_)).ProviderPath
  }
)
$resolvedResultPath = Resolve-Path (Join-Path $repoRoot $config.TestResult.OutputPath) -ErrorAction SilentlyContinue
if ($resolvedResultPath) {
  $config.TestResult.OutputPath = $resolvedResultPath.ProviderPath
} else {
  $config.TestResult.OutputPath = Join-Path $repoRoot 'out/test-results/pester.xml'
}
if (-not $config.TestResult.OutputPath) {
  $config.TestResult.OutputPath = Join-Path $repoRoot 'out/test-results/pester.xml'
}

if ($Tag) {
  $config.Filter.Tag = @($Tag)
}
if ($ExcludeTag) {
  $config.Filter.ExcludeTag = @($ExcludeTag)
}

if ($CI) {
  $resultsPath = $config.TestResult.OutputPath
  $resultsDir = Split-Path $resultsPath -Parent
  if (-not (Test-Path $resultsDir)) { New-Item -ItemType Directory -Path $resultsDir -Force | Out-Null }
  $config.TestResult.Enabled = $true
  Write-Host "CI mode: writing Pester results to $resultsPath"
} else {
  $config.TestResult.Enabled = $false
}

Write-Host "Invoking Pester with tags: $($config.Filter.Tag -join ', ')" -ForegroundColor Cyan
Invoke-Pester -Configuration $config

# SIG # Begin signature block
# MIIFpwYJKoZIhvcNAQcCoIIFmDCCBZQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDYd2uoPAkTXPJb
# bn+j5BoktSlFrWLc2tx3vJ8l5hj/eaCCAxYwggMSMIIB+qADAgECAhAsVIQg030T
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
# BAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEII11SC6wt7Xz
# Nju6w2mLIcqzI70/iCgkEho6gi7yzw2NMA0GCSqGSIb3DQEBAQUABIIBAC+lvCsZ
# Hbrkd9OqgXZbmZ2BQk6bH6LgGEiCG24cb1mz52cjtD3QW38HO4oJyL4rhlpaG/1y
# Avqgi0HcF56b7EgTQfUTn7etfnNbbnBxBPaNeJW6zDXLNPOKGose2gzBsLF3EmfV
# QGa+Flp/9WEqfyLKEgvTmvvZx5dCRIlPCPUeON9yK95fqfASBkuEYdtTrVD3/e5b
# cqf5fAxqzHgKzbS4+hhvAqTjBlhA6SWn1tw8P2mkDE2mzFQUCGOkDTQsdAhAE+Pt
# kf1zEvlibzM7nLgHyTw2dJ9w/a/+inzfycs6VDL83vXvGG98VgeSXpAbPyf5JpSp
# V2v3hQPBat7gvgo=
# SIG # End signature block
