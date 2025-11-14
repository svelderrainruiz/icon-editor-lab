#Requires -Version 7.0
<#
.SYNOPSIS
  Runs fork-mode and trusted-mode signing batches locally to mirror CI behavior.

.DESCRIPTION
  - Prepares SIGN_ROOT by copying repo scripts (tools/, scripts/) plus sample payloads.
  - Generates an ephemeral certificate for each mode and runs Invoke-ScriptSigningBatch.ps1.
  - Prints the summary output so we can compare with GitHub runners.

.PARAMETER SignRoot
  Directory to stage unsigned artifacts. Defaults to 'out'.

.PARAMETER MaxFiles
  Max script count to process (passed through to the batch helper).

.PARAMETER TimeoutSeconds
  Timeout for timestamping; batch helper uses it for per-file waits.

.PARAMETER ToolsOnly
  Limit the test payload to scripts under tools/.

.PARAMETER ScriptsOnly
  Limit the test payload to scripts under scripts/.

.PARAMETER SkipToolTests
  Skip running the harness Pester suite (tools and scripts tags). By default the suite runs.

.NOTES
  Every run captures a transcript under out/local-signing-logs for traceability.
#>

[CmdletBinding()]
param(
  [string]$SignRoot = 'out',
  [int]$MaxFiles = 200,
  [int]$TimeoutSeconds = 20,
  [string]$TimestampServer = 'https://timestamp.digicert.com',
  [switch]$ToolsOnly,
  [switch]$ScriptsOnly,
  [switch]$IncludeSamples = $true,
  [switch]$SimulateTimestampFailure,
  [switch]$SkipToolTests,
  [string[]]$ExcludePaths = @('local-signing-logs','local-ci')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($ToolsOnly -and $ScriptsOnly) {
  throw "Use either -ToolsOnly or -ScriptsOnly, not both."
}

function Test-IsExcludedPath {
  param(
    [string]$RelativePath,
    [string[]]$Excludes
  )
  if (-not $RelativePath) { return $false }
  $segments = $RelativePath -split '[\\/]' | Where-Object { $_ }
  foreach ($segment in $segments) {
    if ($Excludes -contains $segment) { return $true }
  }
  return $false
}

function Get-RootsToCopy {
  if ($ToolsOnly)   { return @('tools') }
  if ($ScriptsOnly) { return @('scripts') }
  return @('tools','scripts')
}

function Prepare-SignRoot {
  param(
    [string]$Root,
    [string[]]$SourceRoots,
    [string[]]$ExcludeFolders
  )
  if (-not (Test-Path $Root)) {
    New-Item -ItemType Directory -Path $Root | Out-Null
  } else {
    Get-ChildItem -Path $Root -Force | Where-Object { $ExcludeFolders -notcontains $_.Name } | Remove-Item -Recurse -Force
    foreach ($folder in $ExcludeFolders) {
      $path = Join-Path $Root $folder
      if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path | Out-Null
      }
    }
  }

  $rootsToCopy = $SourceRoots

  foreach ($rr in $rootsToCopy) {
    $src = Join-Path $PWD $rr
    if (-not (Test-Path $src)) { continue }
    Get-ChildItem -Path $src -Include *.ps1,*.psm1 -Recurse -File |
      ForEach-Object {
        $relative = $_.FullName.Substring($PWD.ToString().Length + 1)
        $dest = Join-Path $Root $relative
        $destDir = Split-Path $dest -Parent
        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
        Copy-Item -Path $_.FullName -Destination $dest -Force
      }
  }

  if ($IncludeSamples) {
    "Write-Output 'Sample payload for signing test.'" | Set-Content -Path (Join-Path $Root 'Sample-Signed.ps1') -Encoding UTF8
    [IO.File]::WriteAllBytes((Join-Path $Root 'sample.exe'), [byte[]](1..16))
  }
}

function Invoke-SigningMode {
  param(
    [string]$ModeLabel,
    [switch]$UseTimestamp,
    [int]$MaxFiles,
    [int]$TimeoutSeconds,
    [string]$TimestampServer,
    [string[]]$ExcludeFolders
  )
  $cert = New-SelfSignedCertificate -Subject "CN=CI Local $ModeLabel" -Type CodeSigningCert -CertStoreLocation Cert:\CurrentUser\My -NotAfter (Get-Date).AddDays(14)
  $thumb = $cert.Thumbprint
  $args = @(
    '-NoLogo','-NoProfile','-File','tools/Invoke-ScriptSigningBatch.ps1',
    '-Root', $SignRoot,
    '-CertificateThumbprint', $thumb,
    '-MaxFiles', $MaxFiles,
    '-TimeoutSeconds', $TimeoutSeconds,
    '-Mode', $ModeLabel
  )
  if ($ExcludeFolders -and $ExcludeFolders.Count -gt 0) {
    Write-Verbose ("[{0}] Excluding folders from signing: {1}" -f $ModeLabel, ($ExcludeFolders -join ', '))
    $args += '-ExcludePaths'
    $args += ($ExcludeFolders -join ',')
  }
  if ($UseTimestamp) {
    $tsa = if ([string]::IsNullOrWhiteSpace($TimestampServer)) { 'https://timestamp.digicert.com' } else { $TimestampServer }
    $args += @('-UseTimestamp','-TimestampServer', $tsa)
    if ($SimulateTimestampFailure -and $ModeLabel -like 'trusted*') {
      $args += '-SimulateTimestampFailure'
    }
  }
  Write-Host "`n== Running mode: $ModeLabel ==" -ForegroundColor Cyan
  $pwshCmd = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
  if (-not $pwshCmd -and $IsWindows) {
    $candidate = Join-Path $PSHOME 'pwsh.exe'
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { $pwshCmd = $candidate }
  }
  if (-not $pwshCmd) { $pwshCmd = 'pwsh' }
  & $pwshCmd @args
}

function Invoke-HarnessTests {
  param([string[]]$Tags)
  $effectiveTags = @($Tags | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  if ($effectiveTags.Count -eq 0) {
    Write-Host "No harness tags selected; skipping Pester harness run." -ForegroundColor Yellow
    return
  }

  $runner = Join-Path $PSScriptRoot 'Invoke-RepoPester.ps1'
  if (-not (Test-Path $runner)) {
    throw "Cannot locate Invoke-RepoPester.ps1 at $runner"
  }

  Write-Host "`n== Running harness Pester suite (tags: $($effectiveTags -join ', ')) ==" -ForegroundColor Cyan
  & $runner -Tag $effectiveTags
}

$transcriptDir = Join-Path $PWD 'out/local-signing-logs'
if (-not (Test-Path $transcriptDir)) { New-Item -ItemType Directory -Path $transcriptDir -Force | Out-Null }
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logPath = Join-Path $transcriptDir "signing-$timestamp.log"
Start-Transcript -Path $logPath | Out-Null

try {
  $selectedRoots = Get-RootsToCopy
  Prepare-SignRoot -Root $SignRoot -SourceRoots $selectedRoots -ExcludeFolders $ExcludePaths
  Invoke-SigningMode -ModeLabel 'fork-local' -MaxFiles $MaxFiles -TimeoutSeconds $TimeoutSeconds -TimestampServer $TimestampServer -ExcludeFolders $ExcludePaths
  Invoke-SigningMode -ModeLabel 'trusted-local' -UseTimestamp -MaxFiles $MaxFiles -TimeoutSeconds $TimeoutSeconds -TimestampServer $TimestampServer -ExcludeFolders $ExcludePaths
  if (-not $SkipToolTests) {
    $harnessTags = @()
    if ($ToolsOnly) {
      $harnessTags = @('tools')
    } elseif ($ScriptsOnly) {
      $harnessTags = @('scripts')
    } else {
      $harnessTags = @('tools','scripts')
    }
    Invoke-HarnessTests -Tags $harnessTags
  } else {
    Write-Host "Skipping harness Pester suite (-SkipToolTests set)." -ForegroundColor Yellow
  }
} finally {
  Stop-Transcript | Out-Null
  Write-Host "Transcript written to $logPath" -ForegroundColor Yellow
}
