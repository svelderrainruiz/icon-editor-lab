#Requires -Version 7.0
[CmdletBinding()]
param(
  [Parameter(Mandatory)] [string]$ReportHtmlPath,
  [Parameter(Mandatory)] [string]$RunDir,
  [Parameter(Mandatory)] [string]$RootDir,
  [string]$OutManifestPath,
  [int]$StaleThresholdSeconds = 300,
  [int]$LargeThresholdBytes = 20971520 # 20 MB
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ReportHtmlPath -PathType Leaf)) {
  throw "compare-report.html not found at '$ReportHtmlPath'"
}

$reportText = Get-Content -LiteralPath $ReportHtmlPath -Raw -ErrorAction Stop
$reportInfo = Get-Item -LiteralPath $ReportHtmlPath
$reportTime = $reportInfo.LastWriteTimeUtc

$imgRegex = '(?i)<img\b[^>]*?\bsrc\s*=\s*(["\''])(?<src>[^"\'']+)\1'
$matches = [System.Text.RegularExpressions.Regex]::Matches($reportText, $imgRegex)
$refs = @()
foreach ($m in $matches) { $refs += $m.Groups['src'].Value }
$refs = $refs | Select-Object -Unique

function Resolve-ImagePath {
  param([string]$src)
  if ([string]::IsNullOrWhiteSpace($src)) { return $null }
  $candidate = $src
  if ([System.Uri]::IsWellFormedUriString($src, [System.UriKind]::Absolute)) { return $src }
  if ([System.IO.Path]::IsPathRooted($src)) { return $src }
  $htmlDir = Split-Path -Parent $ReportHtmlPath
  $p = Join-Path $htmlDir $src
  if (Test-Path -LiteralPath $p) { return (Resolve-Path -LiteralPath $p).ProviderPath }
  $p = Join-Path $RunDir $src
  if (Test-Path -LiteralPath $p) { return (Resolve-Path -LiteralPath $p).ProviderPath }
  return $p
}

function Get-Category { param([string]$p)
  $name = [System.IO.Path]::GetFileName($p)
  if ($name -match '(?i)bd|block') { return 'bd' }
  if ($name -match '(?i)fp|front') { return 'fp' }
  if ($name -match '(?i)attr|icon') { return 'attr' }
  return 'other'
}

$images = @()
$hashGroups = @{}
$existCount = 0; $missingCount = 0; $zeroCount = 0; $largeCount = 0; $staleCount = 0
foreach ($src in $refs) {
  $resolved = Resolve-ImagePath -src $src
  $exists = Test-Path -LiteralPath $resolved -PathType Leaf
  $size = $null; $mtimeUtc = $null; $sha = $null; $stale = $false; $zero = $false; $large = $false
  if ($exists) {
    $fi = Get-Item -LiteralPath $resolved
    $size = [int64]$fi.Length
    $mtimeUtc = $fi.LastWriteTimeUtc
    $delta = [int]([TimeSpan]::FromTicks(($reportTime - $mtimeUtc).Ticks).TotalSeconds)
    if ($delta -gt $StaleThresholdSeconds) { $stale = $true; $staleCount++ }
    if ($size -eq 0) { $zero = $true; $zeroCount++ }
    if ($size -gt $LargeThresholdBytes) { $large = $true; $largeCount++ }
    $sha = (Get-FileHash -LiteralPath $resolved -Algorithm SHA256).Hash.ToLowerInvariant()
    if (-not $hashGroups.ContainsKey($sha)) { $hashGroups[$sha] = @() }
    $hashGroups[$sha] += $resolved
    $existCount++
  } else {
    $missingCount++
  }
  $images += [pscustomobject]@{
    src         = $src
    resolved    = $resolved
    exists      = $exists
    size        = $size
    mtimeUtc    = if ($mtimeUtc) { $mtimeUtc.ToString('o') } else { $null }
    sha256      = $sha
    category    = Get-Category -p $resolved
    stale       = $stale
    zero        = $zero
    large       = $large
  }
}

$dupGroups = @()
foreach ($k in $hashGroups.Keys) {
  $arr = $hashGroups[$k] | Select-Object -Unique
  if ($arr.Count -gt 1) {
    $dupGroups += [pscustomobject]@{ sha256 = $k; count = $arr.Count; paths = $arr }
  }
}

$manifest = [pscustomobject]@{
  schema     = 'compare-report/images@v1'
  report     = $ReportHtmlPath
  reportTime = $reportTime.ToString('o')
  totals     = [pscustomobject]@{
    references = $refs.Count
    existing   = $existCount
    missing    = $missingCount
    zeroSize   = $zeroCount
    largeSize  = $largeCount
    stale      = $staleCount
    dupGroups  = $dupGroups.Count
  }
  images     = $images
  duplicates = $dupGroups
}

if (-not $OutManifestPath) { $OutManifestPath = Join-Path $RunDir 'compare-image-manifest.json' }
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutManifestPath -Encoding utf8

$summary = [pscustomobject]@{
  label         = Split-Path -Leaf $RunDir
  manifestPath  = $OutManifestPath
  references    = $refs.Count
  existing      = $existCount
  missing       = $missingCount
  zeroSize      = $zeroCount
  largeSize     = $largeCount
  stale         = $staleCount
  duplicateSets = $dupGroups.Count
  updatedAt     = (Get-Date).ToString('o')
}
$summary | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $RootDir 'compare-image-summary.json') -Encoding utf8

Write-Output $OutManifestPath

function Test-ValidLabel {
  param([Parameter(Mandatory)][string]$Label)
  if ($Label -notmatch '^[A-Za-z0-9._-]{1,64}$') { throw "Invalid label: $Label" }
}

function Invoke-WithTimeout {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][scriptblock]$ScriptBlock,
    [Parameter()][int]$TimeoutSec = 600
  )
  $job = Start-Job -ScriptBlock $ScriptBlock
  if (-not (Wait-Job $job -Timeout $TimeoutSec)) {
    try { Stop-Job $job -Force } catch {}
    throw "Operation timed out in $TimeoutSec s"
  }
  Receive-Job $job -ErrorAction Stop
}