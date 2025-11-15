#!/usr/bin/env pwsh
<#
  Insight Synch v2 – finished PowerShell pre-commit hook (T + 15 d)
  • Idempotent, success path ≤ 5 s
  • For each staged *.insight.json:
      – Fast JSON-lint (round-trip ConvertFrom/To-Json)
      – Parse latest BEGIN/END block for "extensionMinVersion"
      – Verify VS Code extension labview-community.seed-insight ≥ that version
  • Delegates deep SHA-256 + field checks to scripts/validate-insight.ps1
  • Aborts commit on any failure
#>

param(
  [string]$GitRoot = (git rev-parse --show-toplevel)
)



Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# -------------------------------------------------------------------
function Test-ExtensionInstalled {
  param(
    [string]$Id,
    [string]$MinVersion = '0.0.0'
  )
  $ext = & code --list-extensions --show-versions 2>$null
  if (-not $ext) { return $true }   # if VS Code CLI missing, skip
  foreach ($line in $ext) {
    if ($line -match "^$Id\s+(?<v>[0-9\.]+)$") {
      return ([version]$Matches.v -ge [version]$MinVersion)
    }
  }
  return $false
}

function Get-MinVersionFromFile([string]$Path) {
  $txt = Get-Content $Path -Raw
  $rx  = '(?ms)BEGIN.*?$(?<b>.*?)^.*?END'
  $m   = [regex]::Matches($txt, $rx)
  if ($m.Count -eq 0) { return '0.0.0' }
  $last = $m[-1].Groups['b'].Value
  if ($last -match '"extensionMinVersion"\s*:\s*"(?<v>[^"]+)"') {
    return $Matches.v
  }
  '0.0.0'
}

# -------------------------------------------------------------------

# Skip main commit logic when running tests
if ($env:SEED_INSIGHT_TEST -eq "1") { return }

$files = git diff --cached --name-only | Where-Object { $_ -match '\.insight\.json$' }
if ($files.Count -eq 0) { exit 0 }

# Pass 1 – fast lint + version check
foreach ($f in $files) {
  try {
    $o = Get-Content $f -Raw | ConvertFrom-Json
    $null = $o | ConvertTo-Json -Compress  # round-trip check
  } catch {
    Write-Error "JSON parse error in '$f' – $_"
    exit 1
  }

  $need = Get-MinVersionFromFile $f
  if (-not (Test-ExtensionInstalled -Id 'labview-community.seed-insight' -MinVersion $need)) {
    Write-Error "VS Code extension labview-community.seed-insight ≥ $need required by $f"
    exit 1
  }
}

# Pass 2 – deep validation (SHA-256, fields)
& "$GitRoot/scripts/validate-insight.ps1" -Path $files
exit $LASTEXITCODE
