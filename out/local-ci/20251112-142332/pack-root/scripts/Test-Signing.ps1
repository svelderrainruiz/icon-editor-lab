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
# uIRPdCHqJ2cTO9aZjxQeCzN1ZcRHlaCCAxYwggMSMIIB+qADAgECAhBFacGRfzgn
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
# BAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIJkAD7dHzs9L
# c4JaWjxhF4Ml9J8T6WORtGGFdJTgpntyMA0GCSqGSIb3DQEBAQUABIIBAJOPcSsK
# SLqsCjks30ekMKvfWzyhYCkKlUpK2kHY+QeOaXoi2rhBJ+t10vQyT+UaekrM66GF
# NOCMYI3uhsWopMGyhLhEsQr+izYiKtQuc8l6X/ATV02cHUDGADLEGrV0Wmw7ZLLt
# E2Q93VqYNK7Tacqd5EPW91YTrXf/b1RvW5HkdqO/2ejyB9GNnrW+tZbFhtAS61xP
# 9EHfA2BNnz079yM163HM1qWeoQTKIOlQg9TesKAjNNccWo2RbZbos3c3qJUdKzOu
# qHouZPnKkt5OQSQNjQ/+MDBAOEfwIgRnjZEfw4hWuVeJHf3dIFGD4FGKNjbz/NXH
# WXZdSWpTtQpzd2M=
# SIG # End signature block
