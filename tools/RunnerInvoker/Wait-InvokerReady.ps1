#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSModuleAutoLoadingPreference = 'None'
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
param(
  [Parameter()][ValidateSet('2021','2023','2025')][string]$LabVIEWVersion = '2023',
  [Parameter()][ValidateSet(32,64)][int]$Bitness = 64,
  [Parameter()][ValidateNotNullOrEmpty()][string]$Workspace = (Get-Location).Path,
  [Parameter()][int]$TimeoutSec = 600
)
param(
  [Parameter(Mandatory)][string]$PipeName,
  [Parameter(Mandatory)][string]$ResultsDir,
  [int]$TimeoutSeconds = 15,
  [int]$Retries = 3,
  [int]$RetryDelaySeconds = 2
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'RunnerInvoker.psm1') -Force

if ($Retries -lt 1) { $Retries = 1 }
if ($TimeoutSeconds -lt 1) { $TimeoutSeconds = 1 }

for ($attempt = 1; $attempt -le $Retries; $attempt++) {
  try {
    $result = Invoke-RunnerRequest -ResultsDir $ResultsDir -Verb 'Ping' -CommandArgs @{ pipe = $PipeName } -TimeoutSeconds $TimeoutSeconds
    if ($result -and $result.pong) {
      Write-Host ("Invoker ping attempt #{0}: ok (pong={1})" -f $attempt, $result.pong) -ForegroundColor Green
      return
    }
    throw "Unexpected ping response: $($result | ConvertTo-Json -Compress)"
  } catch {
    if ($attempt -ge $Retries) {
      throw "Invoker ping failed after $Retries attempt(s): $($_.Exception.Message)"
    }
    Write-Host ("Invoker ping attempt #{0} failed: {1}. Retrying in {2}s..." -f $attempt, $_.Exception.Message, $RetryDelaySeconds) -ForegroundColor Yellow
    Start-Sleep -Seconds ([math]::Max(1,$RetryDelaySeconds))
  }
}

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