# Sign-Scripts.ps1
[CmdletBinding()]
param(
  [Parameter()][string]$Thumbprint,
  [Parameter()][string]$SearchRoot = (Get-Location).Path,
  [Parameter()][string[]]$Include = @("*.ps1","*.psm1"),
  [Parameter()][string[]]$ExcludeDirs = @(".git",".github",".venv","node_modules"),
  [switch]$SkipTimestamp,
  [Parameter()][ValidateRange(1,1000)][int]$ProgressInterval = 25,
  [Parameter()][ValidateRange(0,1000)][int]$ThrottleMilliseconds = 0
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'; $PSModuleAutoLoadingPreference='None'
if (-not (Test-Path -LiteralPath $SearchRoot -PathType Container)) {
  throw "Search root not found: $SearchRoot"
}
Write-Host "Signing scripts under: $SearchRoot"
$includeMatchers = @(
  $Include | ForEach-Object {
    if ($_ -and $_.Trim()) {
      [System.Management.Automation.WildcardPattern]::new($_.Trim(),'IgnoreCase')
    }
  }
)
if ($includeMatchers.Count -eq 0) {
  $includeMatchers = @([System.Management.Automation.WildcardPattern]::new('*','IgnoreCase'))
}
function Get-GitTrackedFiles {
  param()
  $gitDir = Join-Path $SearchRoot '.git'
  if (-not (Test-Path -LiteralPath $gitDir -PathType Container)) {
    return @()
  }
  Push-Location $SearchRoot
  try {
    $arguments = @('ls-files','-z','--','*.ps1','*.psm1')
    $output = & git @arguments 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $output) {
      return @()
    }
    return $output -split "`0" | Where-Object { $_ }
  }
  finally {
    Pop-Location
  }
}
function Get-CodeSigningCert {
  param([string]$Thumbprint)
  if ($Thumbprint) {
    $c = Get-ChildItem Cert:\CurrentUser\My\$Thumbprint -ErrorAction SilentlyContinue
    if ($c) { return $c }
  }
  $c = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.HasPrivateKey -and $_.EnhancedKeyUsageList.FriendlyName -contains 'Code Signing' } | Select-Object -First 1
  if (-not $c) { throw 'No suitable code-signing certificate found.' }
  return $c
}
$cert = Get-CodeSigningCert -Thumbprint $Thumbprint
$gitCandidates = Get-GitTrackedFiles
if ($gitCandidates.Count -gt 0) {
  Write-Host ("Discovered {0} git-tracked candidate(s) via ls-files." -f $gitCandidates.Count)
  $candidates = @(
    $gitCandidates | ForEach-Object {
      $path = Join-Path $SearchRoot $_
      if (Test-Path -LiteralPath $path -PathType Leaf) { Get-Item -LiteralPath $path }
    } | Where-Object { $_ }
  )
}
else {
  Write-Host 'git ls-files returned no matches; falling back to filesystem enumeration.'
  $candidates = @(Get-ChildItem -LiteralPath $SearchRoot -Recurse -File)
}
Write-Host ("Discovered {0} candidate file(s) before filtering." -f $candidates.Count)
$files = @($candidates | Where-Object {
  $rel = $_.FullName.Substring($SearchRoot.Length).TrimStart('\','/')
  if ($ExcludeDirs | Where-Object { $rel -like ("{0}\*" -f $_) }) {
    return $false
  }
  foreach ($matcher in $includeMatchers) {
    if ($matcher.IsMatch($_.Name)) { return $true }
  }
  return $false
})
$total = $files.Count
if ($total -eq 0) {
  Write-Warning 'No files matched the signing criteria; nothing to do.'
  return
}
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$processed = 0
foreach ($f in $files) {
  $sig = Get-AuthenticodeSignature -LiteralPath $f.FullName
  if ($sig.Status -ne 'Valid') {
    if ($SkipTimestamp) {
      Write-Verbose ("Signing {0} without timestamp (ephemeral cert)." -f $f.FullName)
      $null = Set-AuthenticodeSignature -LiteralPath $f.FullName -Certificate $cert
    }
    else {
      Write-Verbose ("Signing {0} with timestamp server." -f $f.FullName)
      $null = Set-AuthenticodeSignature -LiteralPath $f.FullName -Certificate $cert -TimestampServer 'http://timestamp.digicert.com'
    }
  }
  $processed++
  $logCheckpoint = ($ProgressInterval -gt 0) -and (($processed -eq 1) -or ($processed % $ProgressInterval -eq 0) -or ($processed -eq $total))
  if ($logCheckpoint) {
    Write-Host ("[{0}/{1}] Last signed: {2}" -f $processed, $total, $f.FullName)
  }
  if ($ThrottleMilliseconds -gt 0) {
    Start-Sleep -Milliseconds $ThrottleMilliseconds
  }
}
$stopwatch.Stop()
Write-Output ("Signed {0} script(s) in {1:n2}s." -f $processed, $stopwatch.Elapsed.TotalSeconds)

# SIG # Begin signature block
# MIIF0QYJKoZIhvcNAQcCoIIFwjCCBb4CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAeum/TPZZqg8Qd
# i6EzfSJ8Soe3EXkn1DH3csWkXlfsnqCCAzIwggMuMIICFqADAgECAhBo3ycLE2Zt
# kkxM9m9eiEKIMA0GCSqGSIb3DQEBCwUAMC8xLTArBgNVBAMMJEljb25FZGl0b3JM
# YWIgRGV2IFNpZ25pbmcgVGVzdCBMb2NhbDAeFw0yNTExMTIxNjA1MjBaFw0yNjEx
# MTIxNjI1MjBaMC8xLTArBgNVBAMMJEljb25FZGl0b3JMYWIgRGV2IFNpZ25pbmcg
# VGVzdCBMb2NhbDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANjmbgyo
# Joz4UzByKkUW97fa74Ug+HoSCAtDn7GPo99Eyfpg5NZ6U+0OXt870NQV7YvTfl/3
# IVgFWO1AHFXZcK4byHWu+TbJcEmHZkmkyrNt0/377yw/aAUpWqi/hmXkdb6mDHUm
# PAt6FUDshcKvAZojhjgrxwKBso5oSerN+LgClaH3h7gnT2956lHqfove3bJKc8mq
# fJ0A+BWTwaXDHT9MHygYTGSt79QMrhZEV7GAJNl3E8sjX25czWML1vXyMb8lqr1T
# JWz8g5hw3leSIpZrdatgDelH92+aIbZjXg8v03PvtCc+8JJDC9pMOEEFNJhhMwdZ
# Au9VtGAQKwAz07UCAwEAAaNGMEQwDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoG
# CCsGAQUFBwMDMB0GA1UdDgQWBBROgMyawl484Flfm/lgXJ8NLv5EqTANBgkqhkiG
# 9w0BAQsFAAOCAQEAJFYqoS2oAGECMLEY8ciDOx8iKaDm9a5UNQrfdVyksVW9GD4c
# lnrN21rWmiJUg4v8R/l+Harh93gf7tmNKCKjtHomFcwzOoH/ikbbi/P3M/ieycP6
# eDgd/s8qRLVcpDAyjEGAt+dzUSrjMpJWUQfW/P5mmbufN5fpwfKLE8OPGOnBiPP2
# UoYipraXrJsPYeT/DUHYK7arUipYDkz00+ivEvv8MgGtz+0dA5qq3QtpQJd2c79y
# j32zxBz5YCV2etO/Yeb1n5d91kgB4Y1Y2ZUxSiSxRsqPCM5xHLrxDZHeSh94CTgU
# +HfXDr185Bia+JahBZ2qgKBR5I5SZDYGjgVcJzGCAfUwggHxAgEBMEMwLzEtMCsG
# A1UEAwwkSWNvbkVkaXRvckxhYiBEZXYgU2lnbmluZyBUZXN0IExvY2FsAhBo3ycL
# E2ZtkkxM9m9eiEKIMA0GCWCGSAFlAwQCAQUAoIGEMBgGCisGAQQBgjcCAQwxCjAI
# oAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIB
# CzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEILpQpsaGP52JDu3kksOD
# G6JT8ZXTuNqrMg5LbA2K283OMA0GCSqGSIb3DQEBAQUABIIBANSFZanwUPmWmmow
# /g6JO3i5Tg2Y5chMD//qT07MPu9RYOmzj3C959IW0QK0ocGGCthYgg3JbOaJgp6n
# SYljEcGDOPtUeT+g2wBK2UHrMPJ5t2n8A/GnrSVAtsltiGNxLnI4J22G3NNEn9/x
# m6N5fAov28naRjO566uVGOwxBTew9lRN4AatK0q6nVjLeyp3djkonQyTRUPSfkJp
# RyrXOoJ5Y154HB9g3EMeYqc7uW4B8QOQO2qTCxjgT+ecfPS2RSm74v2d+59MbIoW
# kYAP1y8qTAACsbREnrIuxfUiVz+q5FCL89s4OWfZML8xqekQmZpncxNYcc48NYQF
# zpO5pL4=
# SIG # End signature block
