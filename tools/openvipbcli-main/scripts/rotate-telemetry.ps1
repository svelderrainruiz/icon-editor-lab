<#
.SYNOPSIS
  Rotate insight.log when it exceeds a given size (in MB).
.DESCRIPTION
  If telemetry/insight.log > MaxSizeMB, moves it with a timestamp suffix.
.PARAMETER MaxSizeMB
  Maximum file size in megabytes before rotation (default 5).
#>
param(
  [int]$MaxSizeMB = 5
)

$logDir  = Join-Path $PSScriptRoot '..\telemetry'
$logFile = Join-Path $logDir 'insight.log'

if (-not (Test-Path $logFile)) { exit 0 }

$sizeBytes = (Get-Item $logFile).Length
if ($sizeBytes -gt ($MaxSizeMB * 1MB)) {
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $rotated  = "$logFile.$timestamp"
    # Use Move-Item so we can specify full destination path
    Move-Item -Path $logFile -Destination $rotated
    # TODO: optionally compress or remove old rotations
}
