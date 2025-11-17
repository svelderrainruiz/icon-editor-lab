# open-new-hooks.ps1
param(
  [string[]]$Files = @(
    '.githooks/synch-hook.ps1',
    '.githooks/synch-hook.sh'
  )
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

foreach ($path in $Files) {
  # Normalize path separators for Windows
  $winPath = $path -replace '/', '\'

  # Create parent directory if missing
  $dir = Split-Path $winPath -Parent
  if ($dir -and -not (Test-Path $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }

  # Touch the file if it doesn't exist
  if (-not (Test-Path $winPath)) {
    New-Item -ItemType File -Path $winPath | Out-Null
  }

  Write-Host "Opening Notepad for $winPath..."
  Start-Process notepad $winPath -Wait   # pauses until you close Notepad
}

Write-Host "`nAll files processed. Remember to save each file before closing Notepad!"
