Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSModuleAutoLoadingPreference = 'None'
<#
.SYNOPSIS
  Read a GitHub Actions job log (zip or text) and optionally locate a pattern.
.DESCRIPTION
  Accepts a local log file that was downloaded via `gh api .../logs`. The job log
  may arrive as a zip archive containing step logs or as raw text. This script
  normalizes the contents to a single UTF-8 string and can search for a pattern,
  returning both the combined content and any regex matches to help diagnose
  errors locally.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory, Position=0)]
  [string]$LogPath,

  [Parameter()]
  [string]$Pattern
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $LogPath)) {
  throw "Log path not found: $LogPath"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem

<#
.SYNOPSIS
Get-LogText: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Get-LogText {

    # ShouldProcess guard: honor -WhatIf / -Confirm
    if (-not $PSCmdlet.ShouldProcess($MyInvocation.MyCommand.Name, 'Execute')) { return }
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param(
    [byte[]]$Bytes
  )

  if (-not $Bytes -or $Bytes.Length -eq 0) {
    return ''
  }

  $isZip = ($Bytes.Length -ge 4 -and $Bytes[0] -eq 0x50 -and $Bytes[1] -eq 0x4B)

  if (-not $isZip) {
    return [System.Text.Encoding]::UTF8.GetString($Bytes)
  }

  $memory = [System.IO.MemoryStream]::new($Bytes)
  try {
    $zip = [System.IO.Compression.ZipArchive]::new($memory)
    $entries = $zip.Entries | Where-Object { $_.Length -gt 0 } | Sort-Object FullName
    $builder = [System.Text.StringBuilder]::new()
    foreach ($entry in $entries) {
      $reader = [System.IO.StreamReader]::new($entry.Open(), [System.Text.Encoding]::UTF8, $true)
      try {
        $builder.AppendLine($reader.ReadToEnd()) | Out-Null
      } finally {
        $reader.Dispose()
      }
    }
    return $builder.ToString()
  } catch {
    throw "Failed to read zip archive: $($_.Exception.Message)"
  } finally {
    $memory.Dispose()
  }
}

$bytes = [System.IO.File]::ReadAllBytes($LogPath)
$content = Get-LogText -Bytes $bytes

$ansiPattern = [regex]'\x1B\[[0-9;]*[A-Za-z]'
$content = $ansiPattern.Replace($content, '')

$matches = $null
if ($Pattern) {
  $regex = [regex]$Pattern
  $matches = $regex.Matches($content)
}

[pscustomobject]@{
  Content = $content
  Matches = $matches
}

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