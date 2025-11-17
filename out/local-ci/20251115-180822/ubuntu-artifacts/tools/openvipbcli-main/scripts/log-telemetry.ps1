<#
.SYNOPSIS
  Very thin wrapper to append a JSON-Lines event to telemetry/insight.log

.PARAMETER Event
  Event name, e.g. "validate.success" or "validate.error"

.PARAMETER Data
  Hashtable or object with event details. Will be serialised to JSON.

.EXAMPLE
  ./log-telemetry.ps1 -Event "validate.success" -Data @{ files = 3 }
#>
param(
  [Parameter(Mandatory)][string]$Event,
  [Parameter()][object]$Data = @{}
)

$log = Join-Path $PSScriptRoot '..\telemetry\insight.log'
$payload = @{
  ts   = (Get-Date -Format o)
  evt  = $Event
  data = $Data
} | ConvertTo-Json -Compress

# ensure folder exists
$dir = Split-Path $log -Parent
if (-not (Test-Path $dir)) { New-Item -Type Directory -Path $dir | Out-Null }

Add-Content -Path $log -Value $payload
