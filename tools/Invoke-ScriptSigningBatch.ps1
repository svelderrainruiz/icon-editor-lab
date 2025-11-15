#Requires -Version 7.0
<#!
.SYNOPSIS
  Signs PowerShell scripts in bulk with optional timestamping and emits progress + summary telemetry.

.DESCRIPTION
  Enumerates *.ps1/*.psm1 files under a target root directory, signs up to MaxFiles using the
  certificate identified by the provided thumbprint, and records aggregate metrics (duration,
  average per-file time, timeout counts). When -UseTimestamp is set, per-file signing is wrapped
  in a background job with a hard timeout to avoid indefinite hangs on flaky RFC-3161 servers.

.PARAMETER Root
  Root directory that contains the script files to sign (e.g., 'unsigned').

.PARAMETER CertificateThumbprint
  Thumbprint of the code-signing certificate already imported into Cert:\CurrentUser\My.

.PARAMETER MaxFiles
  Upper bound on the number of scripts to sign this run. Files are processed in alphabetical order.

.PARAMETER MaxFilesPerBatch
  Optional per-run cap when operating in fork mode. When SamplingMode is not 'None',
  this limits how many files are actually signed from the discovered set.

.PARAMETER TimeoutSeconds
  Timeout applied to each timestamped signing attempt. Ignored when -UseTimestamp is not supplied.

.PARAMETER UseTimestamp
  Enables RFC-3161 timestamping. If the timestamp attempt times out/fails, the script will retry
  without timestamp and record the fallback in the summary metrics.

.PARAMETER TimestampServer
  RFC-3161 server URL. Defaults to https://timestamp.digicert.com when -UseTimestamp is specified.

.PARAMETER Mode
  Friendly label included in progress + summary output (e.g., 'fork' or 'trusted').

.PARAMETER SummaryPath
  Optional path to append a bullet point (e.g., $env:GITHUB_STEP_SUMMARY) summarizing the signing run.

.PARAMETER SamplingMode
  Controls how fork mode subsamples candidates when MaxFilesPerBatch > 0. Allowed values:
  'None' (default, no sampling), 'First' (first N files), or 'Random' (random N files).

.PARAMETER EmitMetrics
  When set, emits a compact JSON metrics object capturing discovery, sampling, and timing data.

#>

[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Root,
  [Parameter(Mandatory)][string]$CertificateThumbprint,
  [int]$MaxFiles = 500,
  [int]$MaxFilesPerBatch = 0,
  [Alias('TimeoutSeconds')]
  [int]$PerFileTimeoutSeconds = 20,
  [switch]$UseTimestamp,
  [string]$TimestampServer = 'https://timestamp.digicert.com',
  [string]$Mode = 'fork',
  [string]$SummaryPath,
  [switch]$SimulateTimestampFailure,
  [switch]$SkipAlreadySigned,
  [int]$VerboseEvery = 25,
  [ValidateSet('None','First','Random')]
  [string]$SamplingMode = 'None',
  [switch]$EmitMetrics
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$rootPath = Resolve-Path -LiteralPath $Root -ErrorAction Stop
$allScripts = Get-ChildItem -LiteralPath $rootPath -Include *.ps1,*.psm1 -Recurse -ErrorAction SilentlyContinue | Sort-Object FullName
if (-not $allScripts) {
  Write-Host "[$Mode] No PowerShell scripts found under '$rootPath'. Nothing to sign."
  return
}

$certPath = "Cert:\CurrentUser\My\$CertificateThumbprint"
$cert = Get-ChildItem -LiteralPath $certPath -ErrorAction Stop

$totalDiscovered = $allScripts.Count
$selected = $allScripts | Select-Object -First $MaxFiles
$capHit = ($selected.Count -lt $totalDiscovered)
$files = @()
$skippedExisting = 0
foreach ($candidate in $selected) {
  if ($SkipAlreadySigned) {
    try {
      $sig = Get-AuthenticodeSignature -FilePath $candidate.FullName -ErrorAction Stop
      if ($sig.Status -eq 'Valid' -and $sig.SignerCertificate -and $sig.SignerCertificate.Thumbprint -eq $cert.Thumbprint) {
        $skippedExisting++
        continue
      }
    } catch {
      # fall through and attempt signing
    }
  }
  $files += $candidate
}
if ($files.Count -eq 0) {
  Write-Host ("[$Mode] All scripts already signed with thumbprint {0}; nothing to do." -f $cert.Thumbprint)
  return
}

if ($SamplingMode -ne 'None' -and $Mode -eq 'fork' -and $MaxFilesPerBatch -gt 0) {
  $preSample = $files.Count
  $sampleCount = if ($MaxFilesPerBatch -lt $preSample) { $MaxFilesPerBatch } else { $preSample }
  if ($sampleCount -lt $preSample) {
    switch ($SamplingMode) {
      'First'  { $files = $files | Select-Object -First $sampleCount }
      'Random' { $files = Get-Random -InputObject $files -Count $sampleCount }
      default  { }
    }
    Write-Host ("[$Mode] Sampling: {0} of {1} candidate scripts using '{2}' mode." -f $files.Count,$preSample,$SamplingMode)
  }
}

if ($capHit) {
  Write-Warning ("[$Mode] Script list truncated to {0} of {1}. Increase MAX_SIGN_FILES to cover all files." -f $files.Count,$totalDiscovered)
}

function Invoke-SignInline {
  param([string]$Path,[System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate)
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  try {
    Set-AuthenticodeSignature -FilePath $Path -Certificate $Certificate -HashAlgorithm SHA256 | Out-Null
    return @{ status = 'ok'; ms = $sw.ElapsedMilliseconds }
  } catch {
    return @{ status = 'error'; ms = $sw.ElapsedMilliseconds; error = $_.Exception.Message }
  } finally {
    $sw.Stop()
  }
}

function Invoke-SignWithTimestamp {
  param([string]$Path,[string]$Thumb,[string]$TimestampUrl,[int]$TimeoutSec,[switch]$SimulateFailure)
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $sb = {
    param($file,$thumb,$tsa)
    $certLocal = Get-ChildItem "Cert:\CurrentUser\My\$thumb"
    if (-not $certLocal) { throw "Certificate $thumb not found in Cert:\CurrentUser\My" }
    Set-AuthenticodeSignature -FilePath $file -Certificate $certLocal -TimestampServer $tsa -HashAlgorithm SHA256 | Out-Null
  }
  if (Get-Command Start-ThreadJob -ErrorAction SilentlyContinue) {
    $job = Start-ThreadJob -ScriptBlock $sb -ArgumentList $Path,$Thumb,$TimestampUrl
  } else {
    $job = Start-Job -ScriptBlock $sb -ArgumentList $Path,$Thumb,$TimestampUrl
  }
  try {
    if (-not (Wait-Job $job -Timeout $TimeoutSec)) {
      try { Stop-Job $job -Force } catch {}
      try { Receive-Job $job -ErrorAction SilentlyContinue | Out-Null } catch {}
      return @{ status = 'timeout'; ms = $sw.ElapsedMilliseconds }
    }
    try {
      Receive-Job $job -ErrorAction Stop | Out-Null
      $result = @{ status = 'ok'; ms = $sw.ElapsedMilliseconds }
      if ($SimulateFailure) {
        $result.status = 'timeout'
      }
      return $result
    } catch {
      $result = @{ status = 'error'; ms = $sw.ElapsedMilliseconds; error = $_.Exception.Message }
      if ($SimulateFailure) {
        $result.status = 'timeout'
        $result.Remove('error') | Out-Null
      }
      return $result
    }
  } finally {
    $sw.Stop()
    try { Remove-Job $job -Force -ErrorAction SilentlyContinue } catch {}
  }
}

$timeoutUsed = 0
$fallbackUsed = 0
$successMs = 0
$fail = 0
$index = 0
$totalWatch = [System.Diagnostics.Stopwatch]::StartNew()
$activityName = "Signing scripts ($Mode)"

foreach ($file in $files) {
  $index++
  Write-Host ("[$Mode] [{0}/{1}] Signing {2}" -f $index,$files.Count,$file.FullName)
  $progressPct = [math]::Round(($index / $files.Count) * 100,2)
  Write-Progress -Activity $activityName -Status ("{0}/{1}" -f $index,$files.Count) -PercentComplete $progressPct
  if ($VerboseEvery -gt 0 -and ($index % $VerboseEvery -eq 0)) {
    Write-Host ("[$Mode] Progress: {0}/{1} (~{2}%) completed." -f $index,$files.Count,$progressPct)
  }
  if ($UseTimestamp) {
    $tsa = if ([string]::IsNullOrWhiteSpace($TimestampServer)) { 'https://timestamp.digicert.com' } else { $TimestampServer }
    $primary = Invoke-SignWithTimestamp -Path $file.FullName -Thumb $CertificateThumbprint -TimestampUrl $tsa -TimeoutSec $PerFileTimeoutSeconds -SimulateFailure:$SimulateTimestampFailure
    switch ($primary.status) {
      'ok'      { Write-Host ("  ✓ ok ({0} ms)" -f $primary.ms); $successMs += $primary.ms }
      'timeout' {
        $timeoutUsed++
        Write-Warning ("  ⏱ TSA timeout after {0} ms; retrying WITHOUT timestamp" -f $primary.ms)
        $secondary = Invoke-SignInline -Path $file.FullName -Certificate $cert
        if ($secondary.status -eq 'ok') {
          $fallbackUsed++
          Write-Host ("  ✓ ok (no timestamp) ({0} ms)" -f $secondary.ms)
          $successMs += $secondary.ms
        } else {
          $fallbackUsed++
          $fail++
          Write-Error "  ✖ failed (no timestamp): $($secondary.error)"
        }
      }
      'error' {
        Write-Warning ("  ⚠ TSA error: {0}; retrying WITHOUT timestamp" -f $primary.error)
        $secondary = Invoke-SignInline -Path $file.FullName -Certificate $cert
        if ($secondary.status -eq 'ok') {
          $fallbackUsed++
          Write-Host ("  ✓ ok (no timestamp) ({0} ms)" -f $secondary.ms)
          $successMs += $secondary.ms
        } else {
          $fallbackUsed++
          $fail++
          Write-Error "  ✖ failed (no timestamp): $($secondary.error)"
        }
      }
    }
  } else {
    $result = Invoke-SignInline -Path $file.FullName -Certificate $cert
    switch ($result.status) {
      'ok'      { Write-Host ("  ✓ ok ({0} ms)" -f $result.ms); $successMs += $result.ms }
      'timeout' { $timeoutUsed++; Write-Warning ("  ⏱ timeout after {0} ms" -f $result.ms); $fail++ }
      'error'   { Write-Warning ("  ⚠ error: {0}" -f $result.error); $fail++ }
    }
  }
}

$totalWatch.Stop()
$completed = $files.Count - $fail
$avgMs = if ($completed -gt 0) { [math]::Round(($successMs / $completed),2) } else { 0 }
$summary = if ($UseTimestamp) {
  "[$Mode] Trusted signing: $completed/$($files.Count) scripts in $([math]::Round($totalWatch.Elapsed.TotalSeconds,2))s (avg ${avgMs} ms, timeouts=$timeoutUsed, fallbacks=$fallbackUsed, skipped=$skippedExisting, cap=$MaxFiles)."
} else {
  "[$Mode] Fork signing: $completed/$($files.Count) scripts in $([math]::Round($totalWatch.Elapsed.TotalSeconds,2))s (avg ${avgMs} ms, timeouts=$timeoutUsed, skipped=$skippedExisting, cap=$MaxFiles)."
}
$activityName = "Signing scripts ($Mode)"
Write-Progress -Activity $activityName -Completed

Write-Host $summary
if ($SummaryPath) {
  try {
    Add-Content -LiteralPath $SummaryPath -Value "- $summary" -ErrorAction Stop
  } catch {
    Write-Warning ("Failed to write summary to {0}: {1}" -f $SummaryPath,$_.Exception.Message)
  }
}

if ($EmitMetrics) {
  try {
    $metrics = [ordered]@{
      mode               = $Mode
      totalDiscovered    = $totalDiscovered
      maxFilesConfigured = $MaxFiles
      maxFilesPerBatch   = $MaxFilesPerBatch
      selectedBeforeSkip = $selected.Count
      skippedExisting    = $skippedExisting
      processed          = $files.Count
      samplingMode       = $SamplingMode
      capHit             = $capHit
      completed          = $completed
      failed             = $fail
      avgMs              = $avgMs
      totalSeconds       = [math]::Round($totalWatch.Elapsed.TotalSeconds,2)
      timeouts           = $timeoutUsed
      fallbacks          = $fallbackUsed
    }
    $metricsJson = $metrics | ConvertTo-Json -Depth 4 -Compress
    if ($SummaryPath) {
      Add-Content -LiteralPath $SummaryPath -Value "- [$Mode] metrics: $metricsJson" -ErrorAction Stop
    } else {
      Write-Host ("[$Mode] metrics: {0}" -f $metricsJson)
    }
  } catch {
    Write-Warning ("Failed to emit metrics: {0}" -f $_.Exception.Message)
  }
}

if ($fail -gt 0) {
  throw "$fail script(s) failed to sign."
}
