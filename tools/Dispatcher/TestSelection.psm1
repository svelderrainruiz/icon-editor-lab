<#
.SYNOPSIS
  TODO: Brief synopsis for this tool function/script. (Auto-generated placeholder)
.DESCRIPTION
  TODO: Expand description. Replace this header with real help content.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-DispatcherPatternMatch {
  param(
    [Parameter(Mandatory)][System.IO.FileInfo]$File,
    [string[]]$Patterns
  )

  if (-not $Patterns -or $Patterns.Count -eq 0) {
    return $false
  }

  foreach ($pattern in $Patterns) {
    if (-not $pattern) { continue }
    $target = if ($pattern -match '[\\/]') { $File.FullName } else { $File.Name }
    if ($target -like $pattern) {
      return $true
    }
  }

  return $false
}

function Invoke-DispatcherIncludeExcludeFilter {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][System.IO.FileInfo[]]$Files,
    [string[]]$IncludePatterns,
    [string[]]$ExcludePatterns
  )

  $filtered = @($Files)
  $includeBefore = $filtered.Count
  $includeAfter = $includeBefore
  $includeApplied = $false

  if ($IncludePatterns -and $IncludePatterns.Count -gt 0) {
    $filtered = @($filtered | Where-Object { Test-DispatcherPatternMatch -File $_ -Patterns $IncludePatterns })
    $includeApplied = $true
    $includeAfter = $filtered.Count
  }

  $excludeBefore = $filtered.Count
  $excludeAfter = $excludeBefore
  $excludeRemoved = 0
  $excludeApplied = $false

  if ($ExcludePatterns -and $ExcludePatterns.Count -gt 0) {
    $excludeApplied = $true
    $filtered = @($filtered | Where-Object { -not (Test-DispatcherPatternMatch -File $_ -Patterns $ExcludePatterns) })
    $excludeAfter = $filtered.Count
    $excludeRemoved = $excludeBefore - $excludeAfter
  }

  [pscustomobject]@{
    Files = $filtered
    Include = [pscustomobject]@{
      Applied = $includeApplied
      Patterns = $IncludePatterns
      Before   = $includeBefore
      After    = $includeAfter
    }
    Exclude = [pscustomobject]@{
      Applied = $excludeApplied
      Patterns = $ExcludePatterns
      Before   = $excludeBefore
      After    = $excludeAfter
      Removed  = $excludeRemoved
    }
  }
}

function Invoke-DispatcherPatternSelfTestSuppression {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][System.IO.FileInfo[]]$Files,
    [string]$PatternSelfTestLeaf = 'Invoke-PesterTests.Patterns.Tests.ps1',
    [string]$SingleTestFile,
    [switch]$LimitToSingle
  )

  $filtered = @($Files)
  $before = $filtered.Count
  $filtered = @(
    $filtered | Where-Object { $_.Name -ne $PatternSelfTestLeaf -and -not ($_.FullName -like "*${PatternSelfTestLeaf}") }
  )
  $removed = $before - $filtered.Count
  $singleCleared = $false

  if ($removed -gt 0 -and $LimitToSingle -and $SingleTestFile) {
    $singleLeaf = Split-Path -Leaf $SingleTestFile
    if ($singleLeaf -eq $PatternSelfTestLeaf) {
      $singleCleared = $true
    }
  }

  [pscustomobject]@{
    Files = $filtered
    Removed = $removed
    SingleCleared = $singleCleared
  }
}

Export-ModuleMember -Function Test-DispatcherPatternMatch, Invoke-DispatcherIncludeExcludeFilter, Invoke-DispatcherPatternSelfTestSuppression

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