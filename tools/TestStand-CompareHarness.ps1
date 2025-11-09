<#
.SYNOPSIS
  Thin wrapper for TestStand: warmup LabVIEW runtime, run LVCompare, and optionally close.

.DESCRIPTION
  Sequentially invokes Warmup-LabVIEWRuntime.ps1 (to ensure LabVIEW readiness), then
  Invoke-LVCompare.ps1 to perform a deterministic compare, and finally optional close helpers.
  Writes a session-index.json with pointers to emitted crumbs and artifacts.

.PARAMETER BaseVi
  Base VI path.

.PARAMETER HeadVi
  Head VI path.

.PARAMETER LabVIEWExePath
  Path to LabVIEW.exe (pinned version/bitness recommended).

.PARAMETER LVCompareExePath
  Path to LVCompare.exe (defaults to canonical install when omitted).

.PARAMETER OutputRoot
  Root folder for all outputs (default tests/results/teststand-session).

.PARAMETER Warmup
  Controls LabVIEW warmup behaviour. `detect` (default) warms up when the helper
  script is available, `spawn` forces a fresh warmup cycle (StopAfterWarmup),
  and `skip` bypasses warmup entirely.

.PARAMETER RenderReport
  Generate compare-report.html during compare.

.PARAMETER Flags
  Additional LVCompare flags forwarded to Invoke-LVCompare.ps1.

.PARAMETER ReplaceFlags
  Replace the default LVCompare flags with the provided -Flags values.

.PARAMETER NoiseProfile
  Selects which LVCompare ignore bundle to apply when -ReplaceFlags is omitted.
  Defaults to 'full' for complete compare detail; pass 'legacy' to restore the historical suppression bundle.

.PARAMETER CloseLabVIEW
  Attempt graceful LabVIEW close via tools/Close-LabVIEW.ps1 at the end.

.PARAMETER CloseLVCompare
  Attempt LVCompare cleanup via tools/Close-LVCompare.ps1 at the end.

.PARAMETER ReportLabel
  Optional label used when emitting LVCompare run reports (defaults to a sanitized base/head label).

.PARAMETER LogPath
  Override the transcript path recorded in the run report. Defaults to INVOCATION_LOG_PATH when available.

.PARAMETER SkipCliCapture
  Skip invoking LVCompare entirely (or honor COMPAREVI_NO_CLI_CAPTURE when set). Useful for testing warning paths
  where lvcompare-capture.json and compare-report.html are expected to be missing.
#>
[CmdletBinding()]
param(
[Parameter(Mandatory)][string]$BaseVi,
[Parameter(Mandatory)][string]$HeadVi,
[Alias('LabVIEWPath')]
[string]$LabVIEWExePath,
[Alias('LVCompareExePath')]
[string]$LVComparePath,
[string]$OutputRoot = 'tests/results/teststand-session',
[ValidateSet('detect','spawn','skip')]
[string]$Warmup = 'detect',
[string[]]$Flags,
[switch]$ReplaceFlags,
[ValidateSet('full','legacy')]
[string]$NoiseProfile = 'full',
[switch]$RenderReport,
[switch]$CloseLabVIEW,
[switch]$CloseLVCompare,
[switch]$SkipCliCapture,
[int]$TimeoutSeconds = 600,
[switch]$DisableTimeout,
[string]$StagingRoot,
[switch]$SameNameHint,
[switch]$AllowSameLeaf,
[string]$ReportLabel,
[string]$LogPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try { Import-Module ThreadJob -ErrorAction SilentlyContinue } catch {}

function New-Dir([string]$p){ if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null } }

function Get-LvCompareLabelSegment {
  param([string]$Value)
  if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
  $safe = ($Value -replace '[^a-zA-Z0-9._-]', '-').Trim('-')
  if ($safe.Length -gt 24) { $safe = $safe.Substring(0,24) }
  if ([string]::IsNullOrWhiteSpace($safe)) { return $null }
  return $safe
}

function New-LvCompareReportLabel {
  param(
    [string]$Explicit,
    [string]$BaseLeaf,
    [string]$HeadLeaf
  )

  if (-not [string]::IsNullOrWhiteSpace($Explicit)) { return $Explicit }
  $parts = [System.Collections.Generic.List[string]]::new()
  $parts.Add('lvcompare')
  $baseSeg = Get-LvCompareLabelSegment $BaseLeaf
  $headSeg = Get-LvCompareLabelSegment $HeadLeaf
  if ($baseSeg) { $parts.Add($baseSeg) }
  if ($headSeg -and $headSeg -ne $baseSeg) { $parts.Add($headSeg) }
  $parts.Add((Get-Date -Format 'yyyyMMddTHHmmss'))
  $label = ($parts -join '-')
  if ($label.Length -gt 80) { $label = $label.Substring(0,80) }
  return $label
}

function Publish-LvCompareRunReport {
  param(
    [string]$RepoRoot,
    [string]$Label,
    [string]$Command,
    [string[]]$SummaryLines,
    [string[]]$Warnings,
    [string]$TranscriptPath,
    [string]$TelemetryPath,
    [bool]$Aborted,
    [string]$AbortReason,
    [hashtable]$Extra
  )

  $reportScript = Join-Path $RepoRoot 'tools' 'report' 'Write-RunReport.ps1'
  if (-not (Test-Path -LiteralPath $reportScript -PathType Leaf)) { return }

  $args = @{
    Kind           = 'lvcompare'
    Label          = $Label
    Command        = $Command
    Summary        = ($SummaryLines | Where-Object { $_ -ne $null } | ForEach-Object { $_.TrimEnd() }) -join [Environment]::NewLine
    Warnings       = ($Warnings | Where-Object { $_ -and $_.Trim() }) -join [Environment]::NewLine
    TranscriptPath = $TranscriptPath
    TelemetryPath  = $TelemetryPath
    Aborted        = $Aborted
    AbortReason    = $AbortReason
  }
  if ($Extra -and $Extra.Count -gt 0) { $args.Extra = $Extra }
  & $reportScript @args | Out-Null
}

function Invoke-WithTimeout {
  param(
    [scriptblock]$Block,
    [int]$TimeoutSeconds,
    [string]$Stage,
    [switch]$DisableTimeout,
    [object[]]$ArgumentList
  )

  if ($DisableTimeout -or $TimeoutSeconds -le 0) {
    if ($ArgumentList) {
      return & $Block @ArgumentList
    }
    return & $Block
  }

  $job = if ($ArgumentList) {
    Start-ThreadJob -ScriptBlock $Block -ArgumentList $ArgumentList
  } else {
    Start-ThreadJob -ScriptBlock $Block
  }
  try {
    if (-not (Wait-Job -Job $job -Timeout $TimeoutSeconds)) {
      try { Stop-Job -Job $job -Force -ErrorAction SilentlyContinue } catch {}
      throw (New-Object System.TimeoutException("Harness stage '$Stage' exceeded ${TimeoutSeconds}s"))
    }
    return Receive-Job -Job $job
  } finally {
    try { Remove-Job -Job $job -Force -ErrorAction SilentlyContinue } catch {}
  }
}

$repo = (Resolve-Path '.').Path

# Determine whether CLI capture should be skipped (switch or env override)
$envSkipCliCapture = [Environment]::GetEnvironmentVariable('COMPAREVI_NO_CLI_CAPTURE')
$skipCliCaptureReason = $null
$skipCliCapture = $SkipCliCapture.IsPresent
if (-not $skipCliCapture -and -not [string]::IsNullOrWhiteSpace($envSkipCliCapture) -and $envSkipCliCapture -ne '0') {
  $skipCliCapture = $true
  $skipCliCaptureReason = 'COMPAREVI_NO_CLI_CAPTURE'
}
if ($SkipCliCapture.IsPresent) {
  $skipCliCaptureReason = 'SkipCliCapture switch'
}

# Resolve OutputRoot to absolute path for deterministic writes
if (-not ([System.IO.Path]::IsPathRooted($OutputRoot))) {
  $OutputRoot = Join-Path $repo $OutputRoot
}

$paths = [ordered]@{
  warmupDir = Join-Path $OutputRoot '_warmup'
  compareDir = Join-Path $OutputRoot 'compare'
}
New-Dir $paths.warmupDir
New-Dir $paths.compareDir

$baseLeaf = Split-Path -Path $BaseVi -Leaf
$headLeaf = Split-Path -Path $HeadVi -Leaf
$sameName = [string]::Equals($baseLeaf, $headLeaf, [System.StringComparison]::OrdinalIgnoreCase)
$baseResolved = (Resolve-Path -LiteralPath $BaseVi -ErrorAction Stop).Path
$headResolved = (Resolve-Path -LiteralPath $HeadVi -ErrorAction Stop).Path
if ($baseResolved -ne $headResolved) {
  $baseResolvedLeaf = Split-Path -Path $baseResolved -Leaf
  $headResolvedLeaf = Split-Path -Path $headResolved -Leaf
  if ([string]::Equals($baseResolvedLeaf, $headResolvedLeaf, [System.StringComparison]::OrdinalIgnoreCase) -and -not $AllowSameLeaf.IsPresent) {
    throw ("LVCompare limitation: staged inputs must have distinct filenames. Received '{0}' and '{1}'." -f $BaseVi, $HeadVi)
  }
}
if ($SameNameHint.IsPresent) {
  $sameName = $true
}
$rawPolicy = $env:LVCI_COMPARE_POLICY
$policy = if ([string]::IsNullOrWhiteSpace($rawPolicy)) { 'cli-only' } else { $rawPolicy }
$rawMode = $env:LVCI_COMPARE_MODE
$mode = if ([string]::IsNullOrWhiteSpace($rawMode)) { 'labview-cli' } else { $rawMode }
$autoCli = $false
if ($sameName -and $policy -ne 'lv-only') {
  $autoCli = $true
  if ($Warmup -ne 'skip') {
    Write-Host "Harness: skipping warmup for same-name VIs (CLI path auto-selected)." -ForegroundColor Gray
    $Warmup = 'skip'
  }
}
if ($policy -eq 'cli-only') {
  if ($Warmup -ne 'skip') {
    Write-Host "Harness: skipping warmup (headless CLI default policy)." -ForegroundColor Gray
    $Warmup = 'skip'
  }
}
if ([string]::IsNullOrWhiteSpace($rawPolicy)) {
  try { [System.Environment]::SetEnvironmentVariable('LVCI_COMPARE_POLICY', $policy, 'Process') } catch {}
}
if ([string]::IsNullOrWhiteSpace($rawMode)) {
  try { [System.Environment]::SetEnvironmentVariable('LVCI_COMPARE_MODE', $mode, 'Process') } catch {}
}

$warmupLog = Join-Path $paths.warmupDir 'labview-runtime.ndjson'
$compareLog = Join-Path $paths.compareDir 'compare-events.ndjson'
$capPath = Join-Path $paths.compareDir 'lvcompare-capture.json'
$reportPath = Join-Path $paths.compareDir 'compare-report.html'
$cap = $null
$warmupRan = $false
$err = $null
$closeLVCompareScript = Join-Path $repo 'tools' 'Close-LVCompare.ps1'
$closeLabVIEWScript = Join-Path $repo 'tools' 'Close-LabVIEW.ps1'
$effectiveTimeout = if ($DisableTimeout) { 0 } else { [Math]::Max(0, [int]$TimeoutSeconds) }

try {
  # 1) Warmup LabVIEW runtime (optional)
  if ($Warmup -ne 'skip') {
    $warmupScript = Join-Path $repo 'tools' 'Warmup-LabVIEWRuntime.ps1'
    if (-not (Test-Path -LiteralPath $warmupScript)) { throw "Warmup-LabVIEWRuntime.ps1 not found at $warmupScript" }
    $warmParams = @{ JsonLogPath = $warmupLog }
    if ($LabVIEWExePath) { $warmParams.LabVIEWPath = $LabVIEWExePath }
    $warmupRunner = {
      param($warmupScriptPath, $warmupParameters)
      & $warmupScriptPath @warmupParameters | Out-Null
    }
    try {
      Invoke-WithTimeout -Block $warmupRunner -TimeoutSeconds $effectiveTimeout -Stage 'warmup' -DisableTimeout:$DisableTimeout -ArgumentList @($warmupScript, $warmParams) | Out-Null
      $warmupRan = $true
    } catch {
      $err = $_.Exception.Message
      throw
    }
  }

  # 2) Invoke LVCompare (deterministic, unless explicitly skipped)
  if ($skipCliCapture) {
    $reason = if ([string]::IsNullOrWhiteSpace($skipCliCaptureReason)) { 'SkipCliCapture requested' } else { $skipCliCaptureReason }
    Write-Warning ("Skipping LVCompare capture ({0})." -f $reason)
    Remove-Item -LiteralPath $capPath -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $reportPath -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $compareLog -ErrorAction SilentlyContinue
  } else {
    $invoke = Join-Path $repo 'tools' 'Invoke-LVCompare.ps1'
    if (-not (Test-Path -LiteralPath $invoke)) { throw "Invoke-LVCompare.ps1 not found at $invoke" }
    $invokeParams = @{
      BaseVi       = $BaseVi
      HeadVi       = $HeadVi
      OutputDir    = $paths.compareDir
      JsonLogPath  = $compareLog
      RenderReport = $RenderReport.IsPresent
      NoiseProfile = $NoiseProfile
    }
    if ($LabVIEWExePath) { $invokeParams.LabVIEWExePath = $LabVIEWExePath }
    if ($LVComparePath) { $invokeParams.LVComparePath = $LVComparePath }
    if ($Flags) { $invokeParams.Flags = $Flags }
    if ($ReplaceFlags) { $invokeParams.ReplaceFlags = $true }
    if ($AllowSameLeaf.IsPresent) { $invokeParams.AllowSameLeaf = $true }
    $compareRunner = {
      param($invokePath, $invokeParameters)
      & $invokePath @invokeParameters | Out-Null
    }
    Invoke-WithTimeout -Block $compareRunner -TimeoutSeconds $effectiveTimeout -Stage 'compare' -DisableTimeout:$DisableTimeout -ArgumentList @($invoke, $invokeParams) | Out-Null
    if (Test-Path -LiteralPath $capPath) { $cap = Get-Content -LiteralPath $capPath -Raw | ConvertFrom-Json }
  }
} catch { $err = $_.Exception.Message }
finally {
  if ($CloseLVCompare -and (Test-Path -LiteralPath $closeLVCompareScript)) {
    try { & $closeLVCompareScript | Out-Null } catch {}
  }
  if ($CloseLabVIEW -and (Test-Path -LiteralPath $closeLabVIEWScript)) {
    try { & $closeLabVIEWScript -MinimumSupportedLVVersion '2025' -SupportedBitness '64' | Out-Null } catch {}
  }
}

# 4) Session index (always write)
$reportExists = Test-Path -LiteralPath $reportPath -PathType Leaf
$warmupNode = [ordered]@{
  mode   = $Warmup
  events = if ($warmupRan) { $warmupLog } else { $null }
}
$compareNode = [ordered]@{
  events  = $compareLog
  capture = $capPath
  report  = $reportExists
}
$compareNode.staging = [ordered]@{
  enabled = [bool]([string]::IsNullOrWhiteSpace($StagingRoot) -eq $false)
  root    = if ([string]::IsNullOrWhiteSpace($StagingRoot)) { $null } else { $StagingRoot }
}
$compareNode.allowSameLeaf = $AllowSameLeaf.IsPresent
if ($cap) {
  if ($cap.PSObject.Properties['command'])   { $compareNode.command = $cap.command }
  if ($cap.PSObject.Properties['cliPath'])   { $compareNode.cliPath = $cap.cliPath }
  if ($cap.PSObject.Properties['environment']) {
    $envNode = $cap.environment
    if ($envNode -and $envNode.PSObject.Properties['cli']) {
      $compareNode.cli = $envNode.cli
    }
  }
}
$compareNode.autoCli = $autoCli
$compareNode.sameName = $sameName
$compareNode.timeoutSeconds = $effectiveTimeout
if ($env:LVCI_COMPARE_POLICY) { $compareNode.policy = $env:LVCI_COMPARE_POLICY }
if ($env:LVCI_COMPARE_MODE)   { $compareNode.mode   = $env:LVCI_COMPARE_MODE }

$index = [ordered]@{
  schema  = 'teststand-compare-session/v1'
  at      = (Get-Date).ToString('o')
  warmup  = $warmupNode
  compare = $compareNode
  outcome = if ($cap) {
    @{ exitCode=[int]$cap.exitCode; seconds=[double]$cap.seconds; command=$cap.command; diff=([bool]($cap.exitCode -eq 1)) }
  } else { $null }
  error   = $err
}
$indexPath = Join-Path $OutputRoot 'session-index.json'
New-Dir $OutputRoot
$index | ConvertTo-Json -Depth 6 | Out-File -LiteralPath $indexPath -Encoding utf8

$exitCode = if ($cap) { [int]$cap.exitCode } else { 1 }
$diffDisplay = if ($index.outcome) { $index.outcome.diff } else { 'unknown' }
$exitDisplay = if ($index.outcome) { $index.outcome.exitCode } else { 'n/a' }
Write-Host ("TestStand Compare Harness result: exit={0} diff={1} capture={2}" -f $exitDisplay, $diffDisplay, $capPath) -ForegroundColor Yellow

try {
  $reportLabelEffective = New-LvCompareReportLabel -Explicit $ReportLabel -BaseLeaf $baseLeaf -HeadLeaf $headLeaf
  $summaryLines = [System.Collections.Generic.List[string]]::new()
  $summaryLines.Add("Base: $BaseVi")
  $summaryLines.Add("Head: $HeadVi")
  $summaryLines.Add(("Warmup: {0} (ran={1})" -f $Warmup, $warmupRan))
  if ($policy) { $summaryLines.Add("Policy: $policy") }
  if ($mode) { $summaryLines.Add("Mode: $mode") }
  $summaryLines.Add(("Auto CLI: {0}" -f $autoCli))
  $summaryLines.Add(("Same-name: {0}" -f $sameName))
  if ($cap) {
    if ($cap.cliPath) { $summaryLines.Add("CLI Path: $($cap.cliPath)") }
    if ($cap.command) { $summaryLines.Add("Command: $($cap.command)") }
    if ($cap.PSObject.Properties['exitCode']) {
      $summaryLines.Add(("Exit Code: {0} (diff={1})" -f $cap.exitCode, ($cap.exitCode -eq 1)))
    }
    if ($cap.PSObject.Properties['seconds']) {
      $summaryLines.Add(("Duration: {0:N2}s" -f [double]$cap.seconds))
    }
  } else {
    $summaryLines.Add('Capture: not produced (see warnings).')
  }
  $summaryLines.Add("Output: $OutputRoot")

  $warningLines = [System.Collections.Generic.List[string]]::new()
  if ($err) { $warningLines.Add($err) }
  if ($Warmup -ne 'skip' -and -not $warmupRan) {
    $warningLines.Add('Warmup requested but no events were recorded.')
  }
  if ($RenderReport -and -not $reportExists) {
    $warningLines.Add('compare-report.html was requested but not emitted.')
  }
  if ($skipCliCapture -and $skipCliCaptureReason) {
    $warningLines.Add(("CLI capture skipped ({0})." -f $skipCliCaptureReason))
  }
  if (-not $cap) {
    $warningLines.Add('lvcompare-capture.json missing or invalid.')
  }

  $logPathEffective = if ($LogPath) { $LogPath } else { [System.Environment]::GetEnvironmentVariable('INVOCATION_LOG_PATH') }
  $commandDisplay = if ($cap -and $cap.command) {
    [string]$cap.command
  } else {
    "TestStand-CompareHarness Base='$BaseVi' Head='$HeadVi'"
  }

  $extra = @{
    capturePath   = if (Test-Path -LiteralPath $capPath -PathType Leaf) { $capPath } else { $null }
    compareLog    = if (Test-Path -LiteralPath $compareLog -PathType Leaf) { $compareLog } else { $null }
    warmupLog     = if ($Warmup -ne 'skip' -and (Test-Path -LiteralPath $warmupLog -PathType Leaf)) { $warmupLog } else { $null }
    reportPath    = if ($reportExists) { $reportPath } else { $null }
    outputRoot    = $OutputRoot
    sessionIndex  = $indexPath
    autoCli       = $autoCli
    sameName      = $sameName
    timeoutSeconds = $effectiveTimeout
    policy        = $policy
    mode          = $mode
  }
  if ($StagingRoot) { $extra.stagingRoot = $StagingRoot }
  if ($cap) {
    if ($cap.PSObject.Properties['exitCode']) { $extra.exitCode = [int]$cap.exitCode }
    if ($cap.PSObject.Properties['seconds']) { $extra.seconds = [double]$cap.seconds }
    if ($cap.PSObject.Properties['cliPath']) { $extra.cliPath = $cap.cliPath }
    if ($cap.PSObject.Properties['command']) { $extra.compareCommand = $cap.command }
  }

  Publish-LvCompareRunReport `
    -RepoRoot $repo `
    -Label $reportLabelEffective `
    -Command $commandDisplay `
    -SummaryLines $summaryLines `
    -Warnings $warningLines `
    -TranscriptPath $logPathEffective `
    -TelemetryPath $indexPath `
    -Aborted:([bool]$err) `
    -AbortReason $err `
    -Extra $extra
} catch {
  Write-Warning ("Failed to write LVCompare run report: {0}" -f $_.Exception.Message)
}

exit $exitCode
