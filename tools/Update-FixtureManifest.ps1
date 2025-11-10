Set-StrictMode -Version Latest
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
param(
  [Parameter()][ValidateSet('2021','2023','2025')][string]$LabVIEWVersion = '2023',
  [Parameter()][ValidateSet(32,64)][int]$Bitness = 64,
  [Parameter()][ValidateNotNullOrEmpty()][string]$Workspace = (Get-Location).Path,
  [Parameter()][int]$TimeoutSec = 600
)
$ErrorActionPreference = 'Stop'
$PSModuleAutoLoadingPreference = 'None'
${ErrorActionPreference} = 'Stop'
<#!
.SYNOPSIS
  Updates fixtures.manifest.json with current SHA256 & size metadata and optional pair digest block.
.DESCRIPTION
  Safely updates the manifest used by Validate-Fixtures. Requires explicit -Allow (or -Force).
  Supports injecting a deterministic pair digest and setting expected outcome hints for targeted tests.
#>
## Manual argument parsing (avoid host-specific switch binding anomalies)
$Allow=$false; $Force=$false; $DryRun=$false; $Output='fixtures.manifest.json'
$InjectPair=$false; $SetExpectedOutcome=''; $SetEnforce=''
for ($i=0; $i -lt $args.Length; $i++) {
  switch -Regex ($args[$i]) {
    '^-Allow$' { $Allow=$true; continue }
    '^-Force$' { $Force=$true; continue }
    '^-DryRun$' { $DryRun=$true; continue }
    '^-Output$' { if ($i+1 -lt $args.Length) { $i++; $Output=$args[$i] }; continue }
    '^-InjectPair$' { $InjectPair=$true; continue }
    '^-SetExpectedOutcome$' { if ($i+1 -lt $args.Length) { $i++; $SetExpectedOutcome=[string]$args[$i] }; continue }
    '^-SetEnforce$' { if ($i+1 -lt $args.Length) { $i++; $SetEnforce=[string]$args[$i] }; continue }
  }
}

if (-not ($Allow -or $Force)) { Write-Error 'Refusing to update manifest without -Allow (or -Force)'; exit 1 }

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..') | Select-Object -ExpandProperty Path
$targets = @('VI1.vi','VI2.vi')
$items = @()
foreach ($t in $targets) {
  $p = Join-Path $repoRoot $t
  if (-not (Test-Path -LiteralPath $p)) { Write-Error "Fixture missing: $t"; exit 2 }
  $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $p).Hash.ToUpperInvariant()
  $role = if ($t -eq 'VI1.vi') { 'base' } else { 'head' }
  $bytes = (Get-Item -LiteralPath $p).Length
  $items += [pscustomobject]@{ path=$t; sha256=$hash; bytes=$bytes; role=$role }
}

# Load prior manifest (to preserve pair.expectedOutcome/enforce if not overridden)
$outPath = Join-Path $repoRoot $Output
$prior = $null
if (Test-Path -LiteralPath $outPath) {
  try { $prior = (Get-Content -LiteralPath $outPath -Raw | ConvertFrom-Json -Depth 6) } catch { $prior = $null }
}

$manifest = [ordered]@{
  schema = 'fixture-manifest-v1'
  generatedAt = (Get-Date).ToString('o')
  items = $items
}

<#
.SYNOPSIS
New-PairBlock: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function New-PairBlock {

    # ShouldProcess guard: honor -WhatIf / -Confirm
    if (-not $PSCmdlet.ShouldProcess($MyInvocation.MyCommand.Name, 'Execute')) { return }
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param([object]$B,[object]$H,[string]$expected,[string]$enforce)
  if (-not $B -or -not $H) { return $null }
  $bSha = ([string]$B.sha256).ToUpperInvariant()
  $hSha = ([string]$H.sha256).ToUpperInvariant()
  $bLen = [int64]$B.bytes
  $hLen = [int64]$H.bytes
  $canonical = 'sha256:{0}|bytes:{1}|sha256:{2}|bytes:{3}' -f $bSha,$bLen,$hSha,$hLen
  $sha = [System.Security.Cryptography.SHA256]::Create()
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($canonical)
  $digest = ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('X2') }) -join ''
  $block = [ordered]@{
    schema    = 'fixture-pair/v1'
    basePath  = [string]$B.path
    headPath  = [string]$H.path
    algorithm = 'sha256'
    canonical = $canonical
    digest    = $digest
  }
  if ($expected) { $block.expectedOutcome = $expected }
  if ($enforce)  { $block.enforce          = $enforce }
  return $block
}

if ($InjectPair -or $SetExpectedOutcome -or $SetEnforce) {
  $base = $items | Where-Object { $_.role -eq 'base' } | Select-Object -First 1
  $head = $items | Where-Object { $_.role -eq 'head' } | Select-Object -First 1
  # Seed expected/enforce from prior unless explicitly set
  $expected = if ($SetExpectedOutcome) { $SetExpectedOutcome } elseif ($prior -and $prior.pair -and $prior.pair.expectedOutcome) { [string]$prior.pair.expectedOutcome } else { 'any' }
  $enf      = if ($SetEnforce) { $SetEnforce } elseif ($prior -and $prior.pair -and $prior.pair.enforce) { [string]$prior.pair.enforce } else { 'notice' }
  $pair = New-PairBlock -B $base -H $head -expected $expected -enforce $enf
  if ($pair) { $manifest['pair'] = $pair }
}

$json = $manifest | ConvertTo-Json -Depth 6
if (Test-Path -LiteralPath $outPath) {
  $existing = Get-Content -LiteralPath $outPath -Raw
  if ($existing -eq $json) {
    Write-Host "Manifest unchanged: $Output"; if ($DryRun) { Write-Host 'DryRun: no write (unchanged)'; }; exit 0
  }
}
if ($DryRun) { Write-Host 'DryRun: manifest differences detected (would write new content)'; exit 0 }
Set-Content -LiteralPath $outPath -Value $json -Encoding UTF8
Write-Host "Updated manifest: $Output"

<#
.SYNOPSIS
Test-ValidLabel: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Test-ValidLabel {
  param([Parameter(Mandatory)][string]$Label)
  if ($Label -notmatch '^[A-Za-z0-9._-]{1,64}$') { throw "Invalid label: $Label" }
}

<#
.SYNOPSIS
Invoke-WithTimeout: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
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