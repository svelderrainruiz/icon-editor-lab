<#
.SYNOPSIS
  TODO: Brief synopsis for this tool function/script. (Auto-generated placeholder)
.DESCRIPTION
  TODO: Expand description. Replace this header with real help content.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$fail = $false
$files = Get-ChildItem -Recurse -File -Include *.ps1,*.psm1,*.psd1,*.yml,*.yaml | Where-Object { -not ($_.FullName -match '\\node_modules\\') }
foreach ($f in $files) {
  if ($f.Name -eq 'Lint-InlineIfInFormat.ps1') { continue }
  $i = 0
  foreach ($line in (Get-Content -LiteralPath $f.FullName)) {
    $i++
    $t = $line.Trim()
    if ($t -match '^#') { continue }
    # Detect the PowerShell format operator specifically: "..." -f ...
    # Flag only when immediately followed by a parenthesized inline 'if' without $() (problematic pattern): -f (if (...))
    if ($t -match '\-f\s*\((?!\$)\s*if\s*\(') {
      Write-Host ("::error file={0},line={1}::Inline 'if' directly after -f detected; precompute into a variable or use $()" -f $f.FullName,$i)
      Write-Host ("  >> {0}" -f $t)
      $fail = $true
    }
  }
}

if ($fail) { exit 2 } else { Write-Host 'Inline-if-in-format lint: OK' }

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