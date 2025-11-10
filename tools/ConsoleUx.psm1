<#
.SYNOPSIS
  TODO: Brief synopsis for this tool function/script. (Auto-generated placeholder)
.DESCRIPTION
  TODO: Expand description. Replace this header with real help content.
#>

Set-StrictMode -Version Latest

function Get-DxLevel {
  [CmdletBinding()]
  param(
    [ValidateSet('quiet','concise','normal','detailed','debug')][string]$Override
  )
  if ($PSBoundParameters.ContainsKey('Override') -and $Override) { return $Override }
  $raw = $env:DX_CONSOLE_LEVEL
  if (-not $raw) { return 'normal' }
  switch -Regex ($raw.ToLowerInvariant()) {
    '^(q|quiet)$'      { return 'quiet' }
    '^(c|concise)$'    { return 'concise' }
    '^(n|normal)$'     { return 'normal' }
    '^(d|detailed)$'   { return 'detailed' }
    '^(dbg|debug)$'    { return 'debug' }
    default            { return 'normal' }
  }
}

function Test-DxAtLeast {
  [CmdletBinding()]
  param(
    [ValidateSet('quiet','concise','normal','detailed','debug')][string]$Level,
    [ValidateSet('quiet','concise','normal','detailed','debug')][string]$AtLeast
  )
  $rank = @{ quiet=0; concise=1; normal=2; detailed=3; debug=4 }
  return ($rank[$Level] -ge $rank[$AtLeast])
}

function Write-Dx {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][string]$Message,
    [ValidateSet('info','warn','error','debug')][string]$Level = 'info',
    [ValidateSet('quiet','concise','normal','detailed','debug')][string]$ConsoleLevel
  )
  $dx = if ($PSBoundParameters.ContainsKey('ConsoleLevel') -and $ConsoleLevel) { $ConsoleLevel } else { Get-DxLevel }
  switch ($Level) {
    'debug' { if (Test-DxAtLeast -Level $dx -AtLeast 'debug') { Write-Host ("[dx] $Message") -ForegroundColor DarkGray } }
    'warn'  { Write-Warning $Message }
    'error' { Write-Error $Message }
    default { if (Test-DxAtLeast -Level $dx -AtLeast 'normal') { Write-Host ("[dx] $Message") } elseif ($dx -eq 'concise') { Write-Host ("[dx] $Message") } }
  }
}

function Write-DxKV {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][hashtable]$Data,
    [string]$Prefix = '[dx]',
    [ValidateSet('quiet','concise','normal','detailed','debug')][string]$ConsoleLevel
  )
  $dx = if ($PSBoundParameters.ContainsKey('ConsoleLevel') -and $ConsoleLevel) { $ConsoleLevel } else { Get-DxLevel }
  if ($dx -eq 'quiet') { return }
  $pairs = @()
  foreach ($k in ($Data.Keys | Sort-Object)) {
    $v = $Data[$k]
    if ($null -eq $v -or ("$v").Length -eq 0) { continue }
    $pairs += ("{0}={1}" -f $k,$v)
  }
  if ($pairs.Count -gt 0) { Write-Host ("{0} {1}" -f $Prefix, ($pairs -join ' ')) }
}

Export-ModuleMember -Function Get-DxLevel,Test-DxAtLeast,Write-Dx,Write-DxKV


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