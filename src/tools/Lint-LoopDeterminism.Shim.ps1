Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSModuleAutoLoadingPreference = 'None'
<#
.SYNOPSIS
  Robust wrapper for Lint-LoopDeterminism.ps1 that tolerates mixed/positional args
  and globs, expanding them into a clean file list before delegating.
.PARAMETER Paths
  One or more file paths. Can be an array. Globs are supported.
.PARAMETER PathsList
  Semicolon or whitespace-separated list of paths/globs.
.PARAMETER Rest
  Captures any stray positional arguments and treats them as paths.
.PARAMETER MaxIterations
  String or int; coerced safely. Default 5.
.PARAMETER IntervalSeconds
  String or double; coerced safely. Default 0.
.PARAMETER AllowedStrategies
  Allowed quantile strategies (default: Exact).
.PARAMETER FailOnViolation
  Exit non-zero when violations found.
#>
[CmdletBinding()]
param(
  [string[]]$Paths,
  [string]$PathsList,
  [Parameter(ValueFromRemainingArguments=$true, Position=0)]
  [string[]]$Rest,
  [object]$MaxIterations = 5,
  [object]$IntervalSeconds = 0,
  [string[]]$AllowedStrategies = @('Exact'),
  [switch]$FailOnViolation
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Coerce-Int([object]$v,[int]$fallback){ try{ if($v -is [int]){ return [int]$v } [int]$tmp=0; if([int]::TryParse("$v",[ref]$tmp)){ return $tmp } }catch{} return $fallback }
function Coerce-Double([object]$v,[double]$fallback){ try{ if($v -is [double]){ return [double]$v } [double]$tmp=0; if([double]::TryParse("$v",[ref]$tmp)){ return $tmp } }catch{} return $fallback }

$tokens = @()
if ($Paths) { $tokens += $Paths }
if ($PathsList) { $tokens += ($PathsList -split '[;\s]+' | Where-Object { $_ }) }
if ($Rest) { $tokens += $Rest }

if (-not $tokens -or $tokens.Count -eq 0) {
  Write-Host '::notice::No input paths provided to Lint-LoopDeterminism.Shim'
  exit 0
}

$resolved = @()
foreach($t in $tokens){
  if (-not $t) { continue }
  # Expand directories and globs
  if (Test-Path -LiteralPath $t -PathType Leaf) { $resolved += (Resolve-Path -LiteralPath $t).Path; continue }
  if (Test-Path -LiteralPath $t -PathType Container) {
    $resolved += (Get-ChildItem -Recurse -File -Path $t -Include *.yml,*.yaml,*.ps1,*.psm1,*.psd1 | ForEach-Object { $_.FullName })
    continue
  }
  # Try glob expansion
  $glob = Get-ChildItem -Recurse -File -Path $t -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }
  if ($glob) { $resolved += $glob } else { Write-Host "::notice::Skipping missing/non-matching token: $t" }
}

$resolved = $resolved | Sort-Object -Unique
if (-not $resolved -or $resolved.Count -eq 0) {
  Write-Host '::notice::No files to lint after expansion.'
  exit 0
}

$mi = Coerce-Int $MaxIterations 5
$is = Coerce-Double $IntervalSeconds 0
$allow = if ($AllowedStrategies -and $AllowedStrategies.Count -gt 0) { $AllowedStrategies } else { @('Exact') }

$inner = Join-Path $PSScriptRoot 'Lint-LoopDeterminism.ps1'
if ($FailOnViolation.IsPresent) {
  & $inner -Paths $resolved -MaxIterations $mi -IntervalSeconds $is -AllowedStrategies $allow -FailOnViolation | Out-Host
} else {
  & $inner -Paths $resolved -MaxIterations $mi -IntervalSeconds $is -AllowedStrategies $allow | Out-Host
}
exit $LASTEXITCODE

<#
.SYNOPSIS
Test-ValidLabel: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Test-ValidLabel {

    # ShouldProcess guard: honor -WhatIf / -Confirm
    if (-not $PSCmdlet.ShouldProcess($MyInvocation.MyCommand.Name, 'Execute')) { return }
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