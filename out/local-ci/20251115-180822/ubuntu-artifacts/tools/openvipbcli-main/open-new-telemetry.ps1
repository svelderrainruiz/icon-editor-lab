# open-new-telemetry.ps1
# Creates stub telemetry scripts + test, opens each in Notepad for review.

$templates = @{

  'scripts/log-telemetry.ps1' = @'
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
'@

  'scripts/log-telemetry.sh' = @'
#!/usr/bin/env sh
# log-telemetry.sh – POSIX shell JSONL logger

event="$1"
data="$2"           # optional JSON string

log_dir="$(dirname "$0")/../telemetry"
log_file="$log_dir/insight.log"
[ -d "$log_dir" ] || mkdir -p "$log_dir"

ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
printf "{\"ts\":\"%s\",\"evt\":\"%s\",\"data\":%s}\n" "$ts" "$event" "${data:-{}}" >> "$log_file"
'@

  'tests/pester/Telemetry.Tests.ps1' = @'
Describe "log-telemetry.ps1" {
    BeforeAll {
        $LogScript = Join-Path $PSScriptRoot "..\..\scripts\log-telemetry.ps1"
        $LogFile   = Join-Path $PSScriptRoot "..\..\telemetry\insight.log"
        if (Test-Path $LogFile) { Remove-Item $LogFile }
    }

    It "appends one line per call" {
        & $LogScript -Event "test" -Data @{foo="bar"}
        & $LogScript -Event "test2" -Data @{x=1}
        (Get-Content $LogFile).Count | Should -Be 2
    }
}
'@
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

foreach ($path in $templates.Keys) {
    $dir = Split-Path $path -Parent
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    $templates[$path] | Set-Content -Encoding utf8 -Path $path
    if ($path -like '*.sh') { git update-index --add --chmod=+x $path 2>$null }

    Write-Host "`nOpening Notepad for $path ..."
    Start-Process notepad $path -Wait
}

Write-Host "`nAll files processed.  Next:"
Write-Host "  git add -A"
Write-Host "  git commit -m 'Add telemetry logging stubs'"
Write-Host "  git push origin main`n"
