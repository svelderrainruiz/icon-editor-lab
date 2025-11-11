[CmdletBinding()]
param(
  [switch] $WarnOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Test-IsRelativeDotSource: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Test-IsRelativeDotSource {

    # ShouldProcess guard: honor -WhatIf / -Confirm
    if (-not $PSCmdlet.ShouldProcess($MyInvocation.MyCommand.Name, 'Execute')) { return }
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param(
    [string] $Line
  )

  if (-not $Line) { return $false }

  $trimmed = $Line.TrimStart()
  if (-not $trimmed.StartsWith('.', [System.StringComparison]::Ordinal)) { return $false }

  $afterDot = $trimmed.Substring(1).TrimStart()
  if ([string]::IsNullOrWhiteSpace($afterDot)) { return $false }

  $firstChar = $afterDot[0]
  if ($firstChar -eq '"') {
    if ($afterDot.Length -eq 1) { return $false }
    $afterDot = $afterDot.Substring(1)
  } elseif ($firstChar -eq "'") {
    if ($afterDot.Length -eq 1) { return $false }
    $afterDot = $afterDot.Substring(1)
  }

  if ($afterDot.StartsWith('./', [System.StringComparison]::Ordinal) -or
      $afterDot.StartsWith('.\\', [System.StringComparison]::Ordinal) -or
      $afterDot.StartsWith('../', [System.StringComparison]::Ordinal) -or
      $afterDot.StartsWith('..\\', [System.StringComparison]::Ordinal)) {
    return $true
  }

  return $false
}

$repoRoot = (Get-Location).Path
$searchPatterns = '*.ps1', '*.psm1', '*.psd1'
$files = Get-ChildItem -LiteralPath $repoRoot -Recurse -File -Include $searchPatterns |
  Where-Object { $_.FullName -notmatch '[\\/]node_modules[\\/]' }

$violations = New-Object System.Collections.Generic.List[object]

foreach ($file in $files) {
  $lines = @(Get-Content -LiteralPath $file.FullName)
  for ($index = 0; $index -lt $lines.Count; $index++) {
    $lineText = $lines[$index]
    $trimmed = $lineText.Trim()
    if ($trimmed.StartsWith('#', [System.StringComparison]::Ordinal)) { continue }

    if (Test-IsRelativeDotSource -Line $lineText) {
      $violations.Add([pscustomobject]@{
        File = $file.FullName
        Line = $index + 1
        Text = $lineText.Trim()
      })
    }
  }
}

if ($violations.Count -eq 0) {
  Write-Host 'Dot-sourcing lint: OK'
  exit 0
}

$annotationType = if ($WarnOnly) { 'warning' } else { 'error' }
$message = 'Avoid dot-sourcing relative paths; use Import-Module or an absolute script path instead.'

foreach ($violation in $violations) {
  Write-Host ("::{0} file={1},line={2}::{3}" -f $annotationType, $violation.File, $violation.Line, $message)
  Write-Host ("  >> {0}" -f $violation.Text)
}

if ($WarnOnly) {
  exit 0
}

exit 2

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