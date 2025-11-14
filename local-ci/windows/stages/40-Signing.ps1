#Requires -Version 7.0
param(
    [Parameter(Mandatory)]
    [pscustomobject]$Context
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot   = $Context.RepoRoot
$signRoot   = $Context.SignRoot
$config     = $Context.Config
$signScript = Join-Path $repoRoot 'scripts' 'Test-Signing.ps1'

if (-not (Test-Path -LiteralPath $signScript)) {
    throw "Signing harness not found at $signScript"
}

function Test-TimestampPreflight {
    param([string]$Url,[int]$TimeoutMs = 5000)
    if ([string]::IsNullOrWhiteSpace($Url)) { return $true }
    try {
        $uri = [System.Uri]::new($Url)
        $host = $uri.Host
        $port = if ($uri.IsDefaultPort) { if ($uri.Scheme -eq 'http') { 80 } else { 443 } } else { $uri.Port }
        $client = New-Object System.Net.Sockets.TcpClient
        $ar = $client.BeginConnect($host, $port, $null, $null)
        $ok = $ar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        try { $client.Close() } catch {}
        return [bool]$ok
    } catch { return $false }
}

$tsUrlEnv   = $env:LOCALCI_SIGN_TS_URL
$tsTimeout  = $env:LOCALCI_SIGN_TIMEOUT
$skipPf     = $env:LOCALCI_SIGN_SKIP_PREFLIGHT
$strictPf   = $env:LOCALCI_SIGN_PREFLIGHT_STRICT
$pfMode     = $env:LOCALCI_SIGN_PREFLIGHT_MODE  # 'warn' (default) | 'strict' | 'skip'
$tsaDefault = if ($tsUrlEnv) { $tsUrlEnv } else { 'https://timestamp.digicert.com' }
$preflightOk = $true

if ($pfMode) {
    switch -Regex ($pfMode.ToLowerInvariant()) {
        '^skip$'   { $skipPf = 'true'; $strictPf = $null }
        '^strict$' { $strictPf = 'true'; $skipPf = $null }
        default    { }
    }
}

$effectiveTimeout = $config.TimestampTimeoutSeconds
if ($tsTimeout -and ($tsTimeout -as [int])) { $effectiveTimeout = [int]$tsTimeout }

 $signParams = @{
    SignRoot       = $signRoot
    MaxFiles       = $config.MaxSignFiles
    TimeoutSeconds = $effectiveTimeout
    SkipToolTests  = $true
}
if ($tsUrlEnv) { $signParams['TimestampServer'] = $tsUrlEnv }

if (-not $skipPf) {
    $probeUrl = $tsaDefault
    $modeText = if ($strictPf) { 'strict' } else { 'warn' }
    Write-Host ("[signing] Preflight TSA connectivity: URL={0}, TimeoutSec={1}, Mode={2}" -f $probeUrl, $effectiveTimeout, $modeText)
    $preflightOk = Test-TimestampPreflight -Url $probeUrl -TimeoutMs 5000
    if ($preflightOk) {
        Write-Host "[signing] Preflight OK" -ForegroundColor Green
    } else {
        $msg = "[signing] Preflight FAILED (TCP connect)."
        if ($strictPf) { throw $msg } else { Write-Warning $msg }
    }
} else {
    Write-Host ("[signing] Preflight skipped. Using TimeoutSec={0}; TSA={1}" -f $effectiveTimeout, $tsaDefault) -ForegroundColor Yellow
}

if ($config.SimulateTimestampFailure) { $signParams['SimulateTimestampFailure'] = $true }

Write-Host "Invoking signing harness for artifacts under $signRoot"
$signLogDir = Join-Path $signRoot 'local-signing-logs'
$signingResult = 'Succeeded'
try {
    & $signScript @signParams
} catch {
    $signingResult = 'Failed'
    throw
} finally {
    $latestTranscript = $null
    if (Test-Path -LiteralPath $signLogDir) {
        $latest = Get-ChildItem -LiteralPath $signLogDir -Filter 'signing-*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($latest) { $latestTranscript = $latest.FullName }
    }
    $summary = [ordered]@{
        TimestampUtc    = (Get-Date).ToUniversalTime().ToString('o')
        SignRoot        = $signRoot
        TimestampServer = $tsaDefault
        TimeoutSeconds  = $effectiveTimeout
        Preflight       = [ordered]@{
            Attempted = (-not $skipPf)
            Mode      = if ($skipPf) { 'skip' } elseif ($strictPf) { 'strict' } else { 'warn' }
            Status    = if ($skipPf) { 'skipped' } elseif ($preflightOk) { 'ok' } else { 'failed' }
        }
        Result          = $signingResult
        Transcript      = $latestTranscript
    }
    $summaryPath = Join-Path $Context.RunRoot 'signing-summary.json'
    try {
        $summary | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
    } catch {
        Write-Warning ("Failed to write signing summary: {0}" -f $_.Exception.Message)
    }
}
