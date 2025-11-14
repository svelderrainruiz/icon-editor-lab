#Requires -Version 7.0
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$BundlePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-Manifest {
  param([string]$Path)
  if ((Test-Path -LiteralPath $Path -PathType Container)) {
    $candidate = Join-Path $Path 'bundle.json'
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
      throw "bundle.json not found under $Path"
    }
    return $candidate
  }
  if ((Test-Path -LiteralPath $Path -PathType Leaf) -and $Path.EndsWith('.zip')) {
    $tempDir = New-Item -ItemType Directory -Force -Path (Join-Path $env:TEMP "semver-bundle-$(Get-Random)")
    Expand-Archive -LiteralPath $Path -DestinationPath $tempDir -Force
    $manifest = Join-Path $tempDir 'bundle.json'
    if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) {
      throw "bundle.json missing inside archive $Path"
    }
    return $manifest
  }
  throw "Unsupported bundle path: $Path"
}

$manifestPath = Resolve-Manifest -Path $BundlePath
$bundleRoot = Split-Path -Parent $manifestPath
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$failures = @()

foreach ($file in $manifest.files) {
  $fullPath = Join-Path $bundleRoot $file.relativePath
  if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
    $failures += "Missing file: $($file.relativePath)"
    continue
  }
  $hash = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash
  if ($hash -ne $file.sha256) {
    $failures += "Hash mismatch ($($file.relativePath)) expected $($file.sha256) actual $hash"
  }
}

if ($failures.Count -gt 0) {
  Write-Error "Bundle verification failed:" -ErrorAction Stop
}

Write-Host "Bundle verified successfully: $bundleRoot" -ForegroundColor Green
