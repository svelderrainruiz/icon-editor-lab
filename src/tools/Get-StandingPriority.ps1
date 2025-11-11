#Requires -Version 7.0
[CmdletBinding()]
param(
  [switch]$Plain,
  [switch]$CacheOnly,
  [switch]$NoCacheUpdate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path '.').Path
$cachePath = Join-Path $repoRoot '.agent_priority_cache.json'

<#
.SYNOPSIS
Write-OutputObject: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Write-OutputObject {

    # ShouldProcess guard: honor -WhatIf / -Confirm
    if (-not $PSCmdlet.ShouldProcess($MyInvocation.MyCommand.Name, 'Execute')) { return }
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param([pscustomobject]$Priority)

  if ($Plain) {
    if ($null -ne $Priority.number -and $Priority.number -ne 0) {
      $title = if ($Priority.title) { $Priority.title } else { '(no title)' }
      Write-Output ("#{0} — {1}" -f $Priority.number, $title)
    } else {
      Write-Output 'Standing priority not set'
    }
  } else {
    $Priority | ConvertTo-Json -Depth 5 | Write-Output
  }
}

<#
.SYNOPSIS
Normalize-PriorityObject: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Normalize-PriorityObject {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param(
    [nullable[int]]$Number,
    [string]$Title,
    [string]$Url,
    [string]$Source,
    [object]$Sequence,
    [object]$Next
  )

  $cleanTitle = if ($Title) { $Title.Trim() } else { $null }
  $cleanUrl = if ($Url) { $Url.Trim() } else { $null }
  if ($cleanUrl -and -not ($cleanUrl -match '^https?://')) { $cleanUrl = $null }

  $obj = [ordered]@{
    number = $Number
    title = $cleanTitle
    url = $cleanUrl
    source = $Source
    retrievedAtUtc = (Get-Date -AsUTC).ToString('o')
  }
  if ($null -ne $Sequence) { $obj.sequence = $Sequence }
  if ($null -ne $Next) { $obj.next = $Next }
  return [pscustomobject]$obj
}

<#
.SYNOPSIS
Parse-OverrideValue: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Parse-OverrideValue {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param([string]$Override)

  if (-not $Override) { return $null }

  $trimmed = $Override.Trim()
  if (-not $trimmed) { return $null }

  # JSON override
  if ($trimmed.StartsWith('{') -or $trimmed.StartsWith('[')) {
    try {
      $obj = $trimmed | ConvertFrom-Json -ErrorAction Stop
      if ($obj -is [System.Collections.IEnumerable]) { $obj = @($obj)[0] }
      if (-not $obj) { return $null }
      $num = $null
      if ($obj.PSObject.Properties.Name -contains 'number') {
        [int]$dummy = 0
        if ([int]::TryParse([string]$obj.number, [ref]$dummy)) { $num = $dummy }
      }
      $title = if ($obj.PSObject.Properties.Name -contains 'title') { [string]$obj.title } else { $null }
      $url = if ($obj.PSObject.Properties.Name -contains 'url') { [string]$obj.url } else { $null }
      $seq = if ($obj.PSObject.Properties.Name -contains 'sequence') { $obj.sequence } else { $null }
      $nxt = if ($obj.PSObject.Properties.Name -contains 'next') { $obj.next } else { $null }
      return Normalize-PriorityObject -Number $num -Title $title -Url $url -Source 'override' -Sequence $seq -Next $nxt
    } catch {
      return $null
    }
  }

  $parts = $trimmed -split '\|', 3
  $rawNumber = $parts[0].Trim()
  if (-not [int]::TryParse($rawNumber, [ref]([int]$null))) { return $null }
  $number = [int]$rawNumber
  $title = if ($parts.Count -gt 1 -and $parts[1]) { $parts[1].Trim() } else { $null }
  $url = if ($parts.Count -gt 2 -and $parts[2]) { $parts[2].Trim() } else { $null }
  return Normalize-PriorityObject -Number $number -Title $title -Url $url -Source 'override'
}

<#
.SYNOPSIS
Try-LoadCache: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Try-LoadCache {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  if (-not (Test-Path -LiteralPath $cachePath -PathType Leaf)) { return $null }
  try {
    $cacheObj = Get-Content -LiteralPath $cachePath -Raw | ConvertFrom-Json -ErrorAction Stop
    if ($cacheObj) {
      $seq = $null; if ($cacheObj.PSObject.Properties.Name -contains 'sequence') { $seq = $cacheObj.sequence }
      $nxt = $null; if ($cacheObj.PSObject.Properties.Name -contains 'next') { $nxt = $cacheObj.next }
      return Normalize-PriorityObject -Number $cacheObj.number -Title $cacheObj.title -Url $cacheObj.url -Source 'cache' -Sequence $seq -Next $nxt
    }
  } catch {}
  return $null
}

<#
.SYNOPSIS
Save-Cache: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Save-Cache {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param([pscustomobject]$Priority)
  if ($NoCacheUpdate) { return }
  try {
    $existing = $null
    if (Test-Path -LiteralPath $cachePath -PathType Leaf) {
      try { $existing = Get-Content -LiteralPath $cachePath -Raw | ConvertFrom-Json -ErrorAction Stop } catch {}
    }
    $payload = [ordered]@{
      number = $Priority.number
      title = $Priority.title
      url = $Priority.url
      cachedAtUtc = (Get-Date -AsUTC).ToString('o')
    }
    $seq = $null
    if ($Priority.PSObject.Properties.Name -contains 'sequence') { $seq = $Priority.sequence }
    elseif ($existing -and $existing.PSObject.Properties.Name -contains 'sequence') { $seq = $existing.sequence }
    if ($null -ne $seq) { $payload.sequence = $seq }

    $nxt = $null
    if ($Priority.PSObject.Properties.Name -contains 'next') { $nxt = $Priority.next }
    elseif ($existing -and $existing.PSObject.Properties.Name -contains 'next') { $nxt = $existing.next }
    if ($null -ne $nxt) { $payload.next = $nxt }

    $payload | ConvertTo-Json -Depth 6 | Out-File -FilePath $cachePath -Encoding utf8
  } catch {}
}

<#
.SYNOPSIS
Try-GitHubPriority: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Try-GitHubPriority {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param([object]$Sequence)

  $gh = $null
  try { $gh = Get-Command gh -ErrorAction Stop } catch { return $null }
  if (-not $gh) { return $null }

  $args = @('issue','list','--label','standing-priority','--state','open','--limit','100','--json','number,title,url')
  try {
    $json = & $gh.Source $args 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $json) { return $null }
    $parsed = $json | ConvertFrom-Json -ErrorAction Stop
    $issues = @()
    if ($parsed -is [System.Collections.IEnumerable]) { $issues = @($parsed) } else { $issues = @($parsed) }
    if ($issues.Count -eq 0) { return $null }

    # Build lookup by number
    $byNumber = @{}
    foreach ($i in $issues) {
      [int]$n = 0
      if ([int]::TryParse([string]$i.number, [ref]$n)) { $byNumber[$n] = $i }
    }

    $chosen = $null
    if ($Sequence) {
      foreach ($s in @($Sequence)) {
        [int]$sn = 0
        if ([int]::TryParse([string]$s, [ref]$sn)) {
          if ($byNumber.ContainsKey($sn)) { $chosen = $byNumber[$sn]; break }
        }
      }
    }
    if (-not $chosen) { $chosen = $issues[0] }

    $num = $null
    if ($chosen.PSObject.Properties.Name -contains 'number') {
      [int]$tmp = 0
      if ([int]::TryParse([string]$chosen.number, [ref]$tmp)) { $num = $tmp }
    }
    $title = if ($chosen.PSObject.Properties.Name -contains 'title') { [string]$chosen.title } else { $null }
    $url = if ($chosen.PSObject.Properties.Name -contains 'url') { [string]$chosen.url } else { $null }
    return Normalize-PriorityObject -Number $num -Title $title -Url $url -Source 'github' -Sequence $Sequence
  } catch {
    return $null
  }
}

$priority = $null

# Load cache early to extract any sequence hints
$cacheCandidate = Try-LoadCache

$overrideValue = $env:AGENT_PRIORITY_OVERRIDE
if ($overrideValue) {
  $priority = Parse-OverrideValue -Override $overrideValue
  # If override didn't include sequence but cache has one, carry it along
  if ($priority -and -not ($priority.PSObject.Properties.Name -contains 'sequence') -and $cacheCandidate -and ($cacheCandidate.PSObject.Properties.Name -contains 'sequence')) {
    $priority = Normalize-PriorityObject -Number $priority.number -Title $priority.title -Url $priority.url -Source $priority.source -Sequence $cacheCandidate.sequence -Next ($cacheCandidate.next)
  }
}

if (-not $priority -and -not $CacheOnly) {
  $seq = $null
  if ($cacheCandidate -and ($cacheCandidate.PSObject.Properties.Name -contains 'sequence')) { $seq = $cacheCandidate.sequence }
  $priority = Try-GitHubPriority -Sequence $seq
  if ($priority) { Save-Cache -Priority $priority }
}

if (-not $priority) {
  $priority = $cacheCandidate
}

if (-not $priority) {
  throw "Standing priority not found. Label 'standing-priority' may be missing or unsecured, and no override is set."
}

Write-OutputObject -Priority $priority

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