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
# bn+j5BoktSlFrWLc2tx3vJ8l5hj/eaCCAxYwggMSMIIB+qADAgECAhBFacGRfzgn
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
# BAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEII11SC6wt7Xz
# Nju6w2mLIcqzI70/iCgkEho6gi7yzw2NMA0GCSqGSIb3DQEBAQUABIIBAHCyfHMT
# 5NNE7lbSi1kPz149OSz/RUoT7f658K93jSIu09vZ/hx4BOzuouj4XVme7jqV/fOg
# 07ypdwLYae4m0relxZ/QYr8e+lt94TRAgMrneCzVFYZZ29rbEKTI+9PnPommkfrQ
# g+ZEK86rJUYz3V4R5AEZ+qvehfoVR5p4WgnH/pJLD3JDw2w3l7m7RV8Dm4mkwZI7
# /ncGjFskNxL+4SLSQurCdwKTh6MFP9vtfhZx3IpyN3tFQLqYk5fCeDA+RKadeOCz
# VUNHAvc45bMxk1/8L0Fn/tKVdeEzDyzyJzqPd7sDBIvGCYS6BKcShEmu6V48DRsE
# w+aLUxEK/8DvH2o=
# SIG # End signature block
