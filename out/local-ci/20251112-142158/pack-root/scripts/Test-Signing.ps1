#Requires -Version 7.0
<#
.SYNOPSIS
  Runs fork-mode and trusted-mode signing batches locally to mirror CI behavior.

.DESCRIPTION
  - Prepares SIGN_ROOT by copying repo scripts (tools/, scripts/) plus sample payloads.
  - Generates an ephemeral certificate for each mode and runs Invoke-ScriptSigningBatch.ps1.
  - Prints the summary output so we can compare with GitHub runners.

.PARAMETER SignRoot
  Directory to stage unsigned artifacts. Defaults to 'out'.

.PARAMETER MaxFiles
  Max script count to process (passed through to the batch helper).

.PARAMETER TimeoutSeconds
  Timeout for timestamping; batch helper uses it for per-file waits.

.PARAMETER ToolsOnly
  Limit the test payload to scripts under tools/.

.PARAMETER ScriptsOnly
  Limit the test payload to scripts under scripts/.

.PARAMETER SkipToolTests
  Skip running the harness Pester suite (tools and scripts tags). By default the suite runs.

.NOTES
  Every run captures a transcript under out/local-signing-logs for traceability.
#>

[CmdletBinding()]
param(
  [string]$SignRoot = 'out',
  [int]$MaxFiles = 200,
  [int]$TimeoutSeconds = 20,
  [switch]$ToolsOnly,
  [switch]$ScriptsOnly,
  [switch]$IncludeSamples = $true,
  [switch]$SimulateTimestampFailure,
  [switch]$SkipToolTests
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($ToolsOnly -and $ScriptsOnly) {
  throw "Use either -ToolsOnly or -ScriptsOnly, not both."
}

function Get-RootsToCopy {
  if ($ToolsOnly)   { return @('tools') }
  if ($ScriptsOnly) { return @('scripts') }
  return @('tools','scripts')
}

function Prepare-SignRoot {
  param(
    [string]$Root,
    [string[]]$SourceRoots
  )
  if (-not (Test-Path $Root)) {
    New-Item -ItemType Directory -Path $Root | Out-Null
  } else {
    $preserve = @('local-signing-logs','local-ci')
    Get-ChildItem -Path $Root -Force | Where-Object { $preserve -notcontains $_.Name } | Remove-Item -Recurse -Force
    foreach ($folder in $preserve) {
      $path = Join-Path $Root $folder
      if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path | Out-Null
      }
    }
  }

  $rootsToCopy = $SourceRoots

  foreach ($rr in $rootsToCopy) {
    $src = Join-Path $PWD $rr
    if (-not (Test-Path $src)) { continue }
    Get-ChildItem -Path $src -Include *.ps1,*.psm1 -Recurse -File |
      ForEach-Object {
        $relative = $_.FullName.Substring($PWD.ToString().Length + 1)
        $dest = Join-Path $Root $relative
        $destDir = Split-Path $dest -Parent
        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
        Copy-Item -Path $_.FullName -Destination $dest -Force
      }
  }

  if ($IncludeSamples) {
    "Write-Output 'Sample payload for signing test.'" | Set-Content -Path (Join-Path $Root 'Sample-Signed.ps1') -Encoding UTF8
    [IO.File]::WriteAllBytes((Join-Path $Root 'sample.exe'), [byte[]](1..16))
  }
}

function Invoke-SigningMode {
  param(
    [string]$ModeLabel,
    [switch]$UseTimestamp,
    [int]$MaxFiles,
    [int]$TimeoutSeconds
  )
  $cert = New-SelfSignedCertificate -Subject "CN=CI Local $ModeLabel" -Type CodeSigningCert -CertStoreLocation Cert:\CurrentUser\My -NotAfter (Get-Date).AddDays(14)
  $thumb = $cert.Thumbprint
  $args = @(
    '-NoLogo','-NoProfile','-File','tools/Invoke-ScriptSigningBatch.ps1',
    '-Root', $SignRoot,
    '-CertificateThumbprint', $thumb,
    '-MaxFiles', $MaxFiles,
    '-TimeoutSeconds', $TimeoutSeconds,
    '-Mode', $ModeLabel
  )
  if ($UseTimestamp) {
    $args += @('-UseTimestamp','-TimestampServer','https://timestamp.digicert.com')
    if ($SimulateTimestampFailure -and $ModeLabel -like 'trusted*') {
      $args += '-SimulateTimestampFailure'
    }
  }
  Write-Host "`n== Running mode: $ModeLabel ==" -ForegroundColor Cyan
  pwsh @args
}

function Invoke-HarnessTests {
  param([string[]]$Tags)
  $effectiveTags = @($Tags | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  if ($effectiveTags.Count -eq 0) {
    Write-Host "No harness tags selected; skipping Pester harness run." -ForegroundColor Yellow
    return
  }

  $runner = Join-Path $PSScriptRoot 'Invoke-RepoPester.ps1'
  if (-not (Test-Path $runner)) {
    throw "Cannot locate Invoke-RepoPester.ps1 at $runner"
  }

  Write-Host "`n== Running harness Pester suite (tags: $($effectiveTags -join ', ')) ==" -ForegroundColor Cyan
  & $runner -Tag $effectiveTags
}

$transcriptDir = Join-Path $PWD 'out/local-signing-logs'
if (-not (Test-Path $transcriptDir)) { New-Item -ItemType Directory -Path $transcriptDir -Force | Out-Null }
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logPath = Join-Path $transcriptDir "signing-$timestamp.log"
Start-Transcript -Path $logPath | Out-Null

try {
  $selectedRoots = Get-RootsToCopy
  Prepare-SignRoot -Root $SignRoot -SourceRoots $selectedRoots
  Invoke-SigningMode -ModeLabel 'fork-local' -MaxFiles $MaxFiles -TimeoutSeconds $TimeoutSeconds
  Invoke-SigningMode -ModeLabel 'trusted-local' -UseTimestamp -MaxFiles $MaxFiles -TimeoutSeconds $TimeoutSeconds
  if (-not $SkipToolTests) {
    $harnessTags = @()
    if ($ToolsOnly) {
      $harnessTags = @('tools')
    } elseif ($ScriptsOnly) {
      $harnessTags = @('scripts')
    } else {
      $harnessTags = @('tools','scripts')
    }
    Invoke-HarnessTests -Tags $harnessTags
  } else {
    Write-Host "Skipping harness Pester suite (-SkipToolTests set)." -ForegroundColor Yellow
  }
} finally {
  Stop-Transcript | Out-Null
  Write-Host "Transcript written to $logPath" -ForegroundColor Yellow
}

# SIG # Begin signature block
# MIIFpwYJKoZIhvcNAQcCoIIFmDCCBZQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDw8wKjt/AUR+ZD
# uIRPdCHqJ2cTO9aZjxQeCzN1ZcRHlaCCAxYwggMSMIIB+qADAgECAhAsVIQg030T
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
# BAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIJkAD7dHzs9L
# c4JaWjxhF4Ml9J8T6WORtGGFdJTgpntyMA0GCSqGSIb3DQEBAQUABIIBANA18iph
# qo5UVDQIaJCKqMI7QZK4kRUqY4/ujvuWthyU7XcFKzU/LgzARkNpdJSUUq8LJOje
# 0bHIZFR9omp3wAng0UIm4A+oGYMU13ZCwExoCc4JDa8CNhHu5zz8T8T8gnOwm/RV
# DyOGgEe+zlh0dKoXOufBqsOOV7YdNEodLdMJGyE+G/U9rXMOHvj8F54zeFe4QGDz
# FUIqoe20pfg19D9R0ESVT4zaCna5xGknjhuyMJPep39wbrBMtH96PSjU6I1k8vQF
# sMqq2bKbLpy2CIIUZEW7m8LWiJpiHUzzlCo3NnpdH/UGWADpFDLLH8N6ns7IXsbS
# k85Q+CAh8vzOhTo=
# SIG # End signature block
