Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:TickInstrumentationEnabled = $true

function Start-TickCounter {
  param([int]$TickMilliseconds = 1)
  if ($TickMilliseconds -lt 1) { $TickMilliseconds = 1 }
  $counter = [pscustomobject]@{
    stopwatch       = [System.Diagnostics.Stopwatch]::StartNew()
    ticks           = 0
    tickMilliseconds= $TickMilliseconds
  }
  return $counter
}

function Invoke-TickDelay {
  param([int]$Milliseconds)
  [System.Threading.Thread]::Sleep($Milliseconds)
}

function Wait-Tick {
  param(
    [pscustomobject]$Counter,
    [int]$Milliseconds = 1
  )
  if ($Milliseconds -lt 1) { $Milliseconds = 1 }
  if ($script:TickInstrumentationEnabled) {
    Invoke-TickDelay -Milliseconds $Milliseconds
  }
  if ($Counter) { $Counter.ticks += 1 }
  return $Counter
}

function Read-TickCounter {
  param([pscustomobject]$Counter)
  if (-not $Counter) { return $null }
  $elapsedMs = 0.0
  if ($Counter.stopwatch) { $elapsedMs = $Counter.stopwatch.Elapsed.TotalMilliseconds }
  return [pscustomobject]@{
    ticks     = $Counter.ticks
    elapsedMs = [double]::Round($elapsedMs,3)
    intervalMs= $Counter.tickMilliseconds
  }
}

function Stop-TickCounter {
  param([pscustomobject]$Counter)
  if ($Counter -and $Counter.stopwatch -and $Counter.stopwatch.IsRunning) {
    $Counter.stopwatch.Stop()
  }
}

Export-ModuleMember -Function Start-TickCounter,Wait-Tick,Read-TickCounter,Stop-TickCounter

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
