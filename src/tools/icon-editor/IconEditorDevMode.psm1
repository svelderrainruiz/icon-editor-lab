#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-IconEditorRepoRoot {
  param([string]$StartPath = (Get-Location).Path)
  try {
    $root = git -C $StartPath rev-parse --show-toplevel 2>$null
    if ($root) {
      return (Resolve-Path -LiteralPath $root.Trim()).Path
    }
  } catch {
    # fall back to supplied path
  }
  return (Resolve-Path -LiteralPath $StartPath).Path
}

function Resolve-IconEditorRoot {
  param([string]$RepoRoot)
  if (-not $RepoRoot) {
    $RepoRoot = Resolve-IconEditorRepoRoot
  }
  $candidates = @(
    Join-PathSegments @($RepoRoot, 'vendor', 'labview-icon-editor'),
    Join-PathSegments @($RepoRoot, 'vendor', 'icon-editor')
  )
  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate -PathType Container) {
      return (Resolve-Path -LiteralPath $candidate).Path
    }
  }
  throw ("Icon editor root not found. Checked: {0}. Vendor the labview-icon-editor repository first." -f ($candidates -join ', '))
}

function Join-PathSegments {
  param(
    [Parameter(Mandatory, Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Parts
  )
  $filtered = @()
  foreach ($part in $Parts) {
    if ([string]::IsNullOrWhiteSpace($part)) { continue }
    $filtered += $part
  }
  if ($filtered.Count -eq 0) { return '' }
  if ($filtered.Count -eq 1) { return $filtered[0] }
  return [System.IO.Path]::Combine([string[]]$filtered)
}

function ConvertTo-IconEditorSafeLabel {
  param([string]$Label)
  if ([string]::IsNullOrWhiteSpace($Label)) { return 'labview-cli' }
  $safe = ($Label -replace '[^a-zA-Z0-9._-]','-')
  if ([string]::IsNullOrWhiteSpace($safe)) { return 'labview-cli' }
  return $safe.ToLowerInvariant()
}

function Enter-IconEditorLabVIEWCliIsolation {
  param(
    [string]$RepoRoot,
    [string]$RunRoot,
    [string]$Label = 'labview-cli'
  )

  $existing = [Environment]::GetEnvironmentVariable('LABVIEWCLI_RESULTS_ROOT','Process')
  $existingNotice = [Environment]::GetEnvironmentVariable('LV_NOTICE_DIR','Process')
  if ($existing) {
    return [pscustomobject]@{
      Changed    = $false
      SessionRoot= $existing
      NoticeDir  = $existingNotice
    }
  }

  if (-not $RepoRoot) {
    $RepoRoot = Resolve-IconEditorRepoRoot
  } else {
    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot -ErrorAction Stop).Path
  }

  $safeLabel = ConvertTo-IconEditorSafeLabel -Label $Label
  $baseRoot = $null
  if ($RunRoot) {
    if (-not (Test-Path -LiteralPath $RunRoot -PathType Container)) {
      New-Item -ItemType Directory -Path $RunRoot -Force | Out-Null
    }
    $baseRoot = Join-PathSegments @($RunRoot, 'labview-cli')
  } else {
    $baseRoot = Join-PathSegments @($RepoRoot, 'tests','results','_cli','sessions')
  }
  if (-not (Test-Path -LiteralPath $baseRoot -PathType Container)) {
    New-Item -ItemType Directory -Path $baseRoot -Force | Out-Null
  }
  $sessionRoot = Join-PathSegments @($baseRoot, ("{0}-{1}" -f $safeLabel, (Get-Date -Format 'yyyyMMddHHmmssfff')))
  New-Item -ItemType Directory -Path $sessionRoot -Force | Out-Null

  $noticeDir = Join-PathSegments @($sessionRoot, 'notice')
  $resultsDir = Join-PathSegments @($sessionRoot, 'tests','results')
  New-Item -ItemType Directory -Path $noticeDir -Force | Out-Null
  New-Item -ItemType Directory -Path $resultsDir -Force | Out-Null

  [Environment]::SetEnvironmentVariable('LABVIEWCLI_RESULTS_ROOT', $sessionRoot, 'Process')
  [Environment]::SetEnvironmentVariable('LV_NOTICE_DIR', $noticeDir, 'Process')

  return [pscustomobject]@{
    Changed    = $true
    SessionRoot= $sessionRoot
    NoticeDir  = $noticeDir
  }
}

function Exit-IconEditorLabVIEWCliIsolation {
  param([psobject]$Handle)
  if (-not $Handle) { return }
  if (-not $Handle.PSObject.Properties['Changed'] -or -not $Handle.Changed) { return }
  [Environment]::SetEnvironmentVariable('LABVIEWCLI_RESULTS_ROOT', $null, 'Process')
  [Environment]::SetEnvironmentVariable('LV_NOTICE_DIR', $null, 'Process')
}

function Get-IconEditorLocalhostLibraryPath {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$IconEditorRoot,
    [string[]]$AdditionalPaths,
    [switch]$AllowMissingAdditionalPaths,
    [string]$Separator = ';'
  )

  if (-not (Test-Path -LiteralPath $IconEditorRoot -PathType Container)) {
    throw "IconEditorRoot '$IconEditorRoot' not found."
  }
  $rootResolved = (Resolve-Path -LiteralPath $IconEditorRoot).Path.TrimEnd('\')
  $pathList = [System.Collections.Generic.List[string]]::new()
  $pathList.Add($rootResolved)

  $additionalList = @()
  if ($AdditionalPaths) {
    $additionalList = @($AdditionalPaths)
  }

  if ($additionalList.Count -gt 0) {
    foreach ($entry in $additionalList) {
      if ([string]::IsNullOrWhiteSpace($entry)) { continue }
      $candidate = $entry
      if (-not [System.IO.Path]::IsPathRooted($entry)) {
        $candidate = [System.IO.Path]::Combine($rootResolved, $entry)
      }
      if (-not (Test-Path -LiteralPath $candidate)) {
        if ($AllowMissingAdditionalPaths) { continue }
        throw "Additional Localhost.LibraryPaths entry '$entry' not found at '$candidate'."
      }
      $resolved = (Resolve-Path -LiteralPath $candidate).Path.TrimEnd('\')
      $pathList.Add($resolved)
    }
  }

  $unique = @(
    $pathList |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { $_.TrimEnd('\') } |
    Select-Object -Unique
  )

  if (-not $unique -or $unique.Count -eq 0) {
    throw "Computed Localhost.LibraryPaths string is empty."
  }

  return ($unique -join $Separator)
}

function Resolve-VendorToolsModulePath {
  param(
    [string]$RepoRoot,
    [psobject]$Context
  )

  if ($Context -and $Context.PSObject.Properties['VendorToolsPath'] -and $Context.VendorToolsPath) {
    return $Context.VendorToolsPath
  }
  if (-not $RepoRoot) {
    $RepoRoot = Resolve-IconEditorRepoRoot
  }
  $candidates = @(
    [System.IO.Path]::Combine($RepoRoot, 'tools', 'VendorTools.psm1'),
    [System.IO.Path]::Combine($RepoRoot, 'src', 'tools', 'VendorTools.psm1'),
    # Fallback relative to this module location: ../VendorTools.psm1 (src/tools/VendorTools.psm1)
    [System.IO.Path]::Combine((Split-Path -Parent $PSScriptRoot), 'VendorTools.psm1')
  )
  if ($env:LOCALCI_DEBUG_DEV_MODE -eq '1') {
    Write-Host "[DevMode] Resolving VendorTools from RepoRoot=$RepoRoot" -ForegroundColor DarkGray
    foreach ($c in $candidates) {
      $exists = Test-Path -LiteralPath $c -PathType Leaf
      Write-Host ("[DevMode] Candidate: {0} -> exists={1}" -f $c, $exists) -ForegroundColor DarkGray
    }
  }
  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
      $resolved = (Resolve-Path -LiteralPath $candidate).Path
      if ($env:LOCALCI_DEBUG_DEV_MODE -eq '1') {
        Write-Host ("[DevMode] Using VendorTools at: {0}" -f $resolved) -ForegroundColor DarkGray
      }
      if ($Context) {
        $Context | Add-Member -NotePropertyName VendorToolsPath -NotePropertyValue $resolved -Force
      }
      return $resolved
    }
  }
  $candList = ($candidates -join '; ')
  throw "VendorTools module not found under 'tools' or 'src/tools'. Checked: $candList"
}

function Resolve-RepoToolFile {
  param(
    [string]$RepoRoot,
    [Parameter(Mandatory)][string[]]$RelativeSegments
  )
  if (-not $RepoRoot) {
    $RepoRoot = Resolve-IconEditorRepoRoot
  }
  $candidates = @()
  $candidates += (Join-PathSegments (@($RepoRoot, 'tools') + $RelativeSegments))
  $candidates += (Join-PathSegments (@($RepoRoot, 'src', 'tools') + $RelativeSegments))
  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
      return (Resolve-Path -LiteralPath $candidate).Path
    }
  }
  return $candidates[0]
}

function Get-IconEditorDevModeStatePath {
  param([string]$RepoRoot)
  if (-not $RepoRoot) {
    $RepoRoot = Resolve-IconEditorRepoRoot
  }
  return Join-PathSegments @($RepoRoot, 'tests', 'results', '_agent', 'icon-editor', 'dev-mode-state.json')
}

function Get-IconEditorDevModeState {
  param([string]$RepoRoot)
  $statePath = Get-IconEditorDevModeStatePath -RepoRoot $RepoRoot
  if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) {
    return [pscustomobject]@{
      Active    = $null
      UpdatedAt = $null
      Source    = $null
      Path      = $statePath
    }
  }

  try {
    $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json -ErrorAction Stop
  } catch {
    throw "Failed to parse icon editor dev-mode state file at '$statePath': $($_.Exception.Message)"
  }

  return [pscustomobject]@{
    Active    = $state.active
    UpdatedAt = $state.updatedAt
    Source    = $state.source
    Path      = $statePath
  }
}

function Set-IconEditorDevModeState {
  param(
    [Parameter(Mandatory)][bool]$Active,
    [string]$RepoRoot,
    [string]$Source
  )

  if (-not $RepoRoot) {
    $RepoRoot = Resolve-IconEditorRepoRoot
  } else {
    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
  }

  $statePath = Get-IconEditorDevModeStatePath -RepoRoot $RepoRoot
  $stateDir = Split-Path -Parent $statePath
  if (-not (Test-Path -LiteralPath $stateDir -PathType Container)) {
    New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
  }

  $payload = [ordered]@{
    schema    = 'icon-editor/dev-mode-state@v1'
    updatedAt = (Get-Date).ToString('o')
    active    = [bool]$Active
    source    = $Source
  }

  $payload | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $statePath -Encoding UTF8
  return Get-IconEditorDevModeState -RepoRoot $RepoRoot
}

function Invoke-IconEditorRogueCheck {
  param(
    [string]$RepoRoot,
    [string]$Stage,
    [switch]$FailOnRogue,
    [switch]$AutoClose,
    [string]$RunRoot,
    [int[]]$Versions,
    [int[]]$Bitness
  )

  try {
    if (-not $RepoRoot) {
      $RepoRoot = Resolve-IconEditorRepoRoot
    } else {
      $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
    }
  } catch {
    $RepoRoot = Resolve-IconEditorRepoRoot
  }

  $detectScript = Resolve-RepoToolFile -RepoRoot $RepoRoot -RelativeSegments @('Detect-RogueLV.ps1')
  if (-not (Test-Path -LiteralPath $detectScript -PathType Leaf)) {
    return $null
  }

  $customLogRoot = $env:LOCALCI_DEV_MODE_LOGROOT
  $customLogResolved = $null
  if ($customLogRoot) {
    try {
      if (-not (Test-Path -LiteralPath $customLogRoot -PathType Container)) {
        New-Item -ItemType Directory -Force -Path $customLogRoot | Out-Null
      }
      $customLogResolved = (Resolve-Path -LiteralPath $customLogRoot).Path
    } catch {
      $customLogResolved = $customLogRoot
      try { New-Item -ItemType Directory -Force -Path $customLogResolved | Out-Null } catch {}
    }
  }

  if ($customLogResolved) {
    $resultsDir = $customLogResolved
  } else {
    $resultsDir = Join-PathSegments @($RepoRoot, 'tests', 'results')
    if (-not (Test-Path -LiteralPath $resultsDir -PathType Container)) {
      try { New-Item -ItemType Directory -Force -Path $resultsDir | Out-Null } catch {}
    }
  }

  if ($customLogResolved) {
    $outputDir = Join-Path $resultsDir 'rogue'
  } else {
    $outputDir = Join-PathSegments @($resultsDir, '_agent', 'icon-editor', 'rogue-lv')
  }
  if (-not (Test-Path -LiteralPath $outputDir -PathType Container)) {
    try { New-Item -ItemType Directory -Force -Path $outputDir | Out-Null } catch {}
  }

  $safeStage = if ($Stage) { ($Stage -replace '[^a-zA-Z0-9_-]','-') } else { 'icon-editor' }
  if ([string]::IsNullOrWhiteSpace($safeStage)) { $safeStage = 'icon-editor' }
  $timestamp = Get-Date -Format 'yyyyMMddTHHmmssfff'
  $outputPath = Join-PathSegments @($outputDir, ("rogue-lv-{0}-{1}.json" -f $safeStage.ToLowerInvariant(), $timestamp))

  $pwshExe = 'pwsh'
  try {
    $cmd = Get-Command -Name 'pwsh' -ErrorAction Stop
    if ($cmd -and $cmd.Source) {
      $pwshExe = $cmd.Source
    } elseif ($cmd -and $cmd.Path) {
      $pwshExe = $cmd.Path
    }
  } catch {}

  $args = @(
    '-NoLogo',
    '-NoProfile',
    '-File', $detectScript,
    '-ResultsDir', $resultsDir,
    '-OutputPath', $outputPath,
    '-LookBackSeconds', '300',
    '-RetryCount', '2',
    '-RetryDelaySeconds', '5'
  )
  if ($env:GITHUB_STEP_SUMMARY) {
    $args += '-AppendToStepSummary'
  }
  if ($FailOnRogue) {
    $args += '-FailOnRogue'
  }

  $exitCode = 0
  try {
    & $pwshExe @args | Out-Null
    $exitCode = $LASTEXITCODE
  } catch {
    Write-Warning ("Detect-RogueLV failed during stage '{0}': {1}" -f $Stage, $_.Exception.Message)
    return $null
  }

  if ($exitCode -ne 0 -and $AutoClose) {
    $isolationHandle = Enter-IconEditorLabVIEWCliIsolation -RepoRoot $RepoRoot -RunRoot $RunRoot -Label ("rogue-{0}" -f ($safeStage ?? 'auto'))
    try {
      try {
        Close-IconEditorLabVIEW -RepoRoot $RepoRoot -IconEditorRoot $null -Versions $Versions -Bitness $Bitness -FailOnRogue:$false -RunRoot $RunRoot | Out-Null
      } catch {
        Write-Warning ("Automatic Close-IconEditorLabVIEW attempt failed: {0}" -f $_.Exception.Message)
      }
      try {
        & $pwshExe @args | Out-Null
        $exitCode = $LASTEXITCODE
      } catch {
        Write-Warning ("Detect-RogueLV retry failed during stage '{0}': {1}" -f $Stage, $_.Exception.Message)
      }
    } finally {
      Exit-IconEditorLabVIEWCliIsolation -Handle $isolationHandle
    }
  }

  if ($exitCode -ne 0) {
    $message = "Rogue LabVIEW/LVCompare processes detected (stage '{0}'). See {1} for details." -f $Stage, $outputPath
    if ($FailOnRogue) {
      throw $message
    } else {
      Write-Warning $message
    }
  }

  return [pscustomobject]@{
    Stage    = $Stage
    ExitCode = $exitCode
    Path     = $outputPath
  }
}

function Write-DevModeScriptLog {
  param(
    [string]$RepoRoot,
    [string]$StageLabel,
    [string]$ScriptPath,
    [string[]]$ArgumentList,
    [object[]]$OutputLines,
    [int]$ExitCode
  )

  if (-not $RepoRoot) {
    $RepoRoot = Resolve-IconEditorRepoRoot
  }
  $resultsDir = Join-PathSegments @($RepoRoot, 'tests', 'results')
  if (-not (Test-Path -LiteralPath $resultsDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $resultsDir | Out-Null
  }
  $logDir = Join-PathSegments @($resultsDir, '_agent', 'icon-editor', 'dev-mode-script')
  if (-not (Test-Path -LiteralPath $logDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
  }

  $label = if ($StageLabel) { $StageLabel } else { [IO.Path]::GetFileNameWithoutExtension($ScriptPath) }
  if (-not $label) { $label = 'dev-mode-script' }
  $label = ($label -replace '[^\w\.\-]', '-').ToLowerInvariant()
  $timestamp = Get-Date -Format 'yyyyMMddTHHmmssfff'
  $logPath = Join-PathSegments @($logDir, ("{0}-{1}.log" -f $label, $timestamp))

  $header = @(
    "# Dev-mode Script Log",
    "timestamp: $(Get-Date -Format 'o')",
    "stage: $label",
    "script: $ScriptPath",
    ("args: {0}" -f ([string]::Join(' ', $ArgumentList))),
    ("exitCode: {0}" -f $ExitCode),
    ''
  )
  $header | Set-Content -LiteralPath $logPath -Encoding utf8
  if ($OutputLines -and $OutputLines.Count -gt 0) {
    $OutputLines | Out-String | Add-Content -LiteralPath $logPath -Encoding utf8
  }
  return $logPath
}

function Invoke-IconEditorDevModeScript {
  param(
    [Parameter(Mandatory)][string]$ScriptPath,
    [string[]]$ArgumentList,
    [string]$RepoRoot,
    [string]$IconEditorRoot,
    [string]$StageLabel
  )

  if (-not $RepoRoot) {
    $RepoRoot = Resolve-IconEditorRepoRoot
  } else {
    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
  }

  if (-not $IconEditorRoot) {
    $IconEditorRoot = Resolve-IconEditorRoot -RepoRoot $RepoRoot
  } else {
    $IconEditorRoot = (Resolve-Path -LiteralPath $IconEditorRoot).Path
  }

  if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
    throw "Icon editor dev-mode script not found at '$ScriptPath'."
  }

  Import-Module (Resolve-VendorToolsModulePath -RepoRoot $RepoRoot -Context $Context) -Force
  $scriptDirectory = Split-Path -Parent $ScriptPath
  $previousLocation = Get-Location

  $pwshCmd = Get-Command pwsh -ErrorAction Stop
  $args = @()
  if ($ArgumentList -and $ArgumentList.Count -gt 0) {
    foreach ($arg in $ArgumentList) {
      if ($null -ne $arg) { $args += [string]$arg }
    }
  } else {
    $args = @('-IconEditorRoot', [string]$IconEditorRoot)
  }

  # Guard against non-scalar argument values sneaking into the list
  foreach ($item in $args) {
    if ($item -is [System.Array]) {
      throw "Dev-mode script arguments contained a non-scalar value. Ensure arguments are flattened into strings."
    }
  }

  Set-Location -LiteralPath $scriptDirectory
  try {
    $scriptOutput = @()
    if ($env:LOCALCI_DEBUG_DEV_MODE -eq '1') {
      Write-Host ("[DevMode] Invoking {0}" -f $ScriptPath) -ForegroundColor DarkGray
      $args | ForEach-Object { Write-Host ("  {0}" -f $_) }
    }
    & $pwshCmd.Source -NoLogo -NoProfile -File $ScriptPath @args 2>&1 |
      Tee-Object -Variable scriptOutput | Out-Host
    $exitCode = $LASTEXITCODE
    $null = Write-DevModeScriptLog -RepoRoot $RepoRoot -StageLabel $StageLabel -ScriptPath $ScriptPath -ArgumentList $args -OutputLines $scriptOutput -ExitCode $exitCode
    if ($exitCode -ne 0) {
      $capturedText = ($scriptOutput | Out-String).Trim()
      $message = "Dev-mode script '$ScriptPath' exited with code $exitCode."
      if (-not [string]::IsNullOrWhiteSpace($capturedText)) {
        $message += [Environment]::NewLine + $capturedText
      }
      throw $message
    }
  }
  finally {
    Set-Location -LiteralPath $previousLocation.Path
  }
}

function ConvertTo-IntList {
  param(
    $Values,
    [int[]]$DefaultValues
  )

  $result = @()
  if ($Values) {
    foreach ($value in $Values) {
      if ($null -eq $value) { continue }
      if ($value -is [array]) {
        foreach ($inner in $value) {
          if ($null -ne $inner) { $result += [int]$inner }
        }
      } else {
        $result += [int]$value
      }
    }
  }

  if ($result.Count -eq 0) {
    $result = @()
    foreach ($default in $DefaultValues) {
      $result += [int]$default
    }
  }

  return $result
}

function Get-DefaultIconEditorDevModeTargets {
  param([string]$Operation)

  $normalized = if ($Operation) { $Operation.ToLowerInvariant() } else { 'compare' }
  switch ($normalized) {
    'buildpackage' {
      return [pscustomobject]@{
        Versions = @(2023)
        Bitness  = @(32, 64)
      }
    }
    default {
      return [pscustomobject]@{
        Versions = @(2025)
        Bitness  = @(64)
      }
    }
  }
}

function Get-IconEditorDevModePolicyPath {
  param([string]$RepoRoot)

  if (-not $RepoRoot) {
    $RepoRoot = Resolve-IconEditorRepoRoot
  } else {
    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
  }

  if ($env:ICON_EDITOR_DEV_MODE_POLICY_PATH) {
    return (Resolve-Path -LiteralPath $env:ICON_EDITOR_DEV_MODE_POLICY_PATH).Path
  }

  return Join-PathSegments @($RepoRoot, 'configs', 'icon-editor', 'dev-mode-targets.json')
}

function Get-IconEditorDevModePolicy {
  param(
    [string]$RepoRoot,
    [switch]$ThrowIfMissing
  )

  $policyPath = Get-IconEditorDevModePolicyPath -RepoRoot $RepoRoot
  if (-not (Test-Path -LiteralPath $policyPath -PathType Leaf)) {
    if ($ThrowIfMissing.IsPresent) {
      throw "Icon editor dev-mode policy not found at '$policyPath'."
    }
    return $null
  }

  try {
    $policyContent = Get-Content -LiteralPath $policyPath -Raw -Encoding UTF8
    $policy = $policyContent | ConvertFrom-Json -AsHashtable -Depth 5
  } catch {
    throw "Failed to parse icon editor dev-mode policy '$policyPath': $($_.Exception.Message)"
  }

  if (-not ($policy -and $policy.ContainsKey('operations'))) {
    if ($ThrowIfMissing.IsPresent) {
      throw "Icon editor dev-mode policy at '$policyPath' is missing the 'operations' node."
    }
    return $null
  }

  return [pscustomobject]@{
    Path       = (Resolve-Path -LiteralPath $policyPath).Path
    Schema     = $policy['schema']
    Operations = $policy['operations']
  }
}

function Get-IconEditorDevModePolicyEntry {
  param(
    [Parameter(Mandatory)][string]$Operation,
    [string]$RepoRoot
  )

  $policy = Get-IconEditorDevModePolicy -RepoRoot $RepoRoot -ThrowIfMissing
  $operations = $policy.Operations
  if (-not $operations) {
    throw "Icon editor dev-mode policy at '$($policy.Path)' does not define any operations."
  }

  $entry = $null
  if ($operations.ContainsKey($Operation)) {
    $entry = $operations[$Operation]
    $operationKey = $Operation
  } else {
    foreach ($key in $operations.Keys) {
      if ($key -and ($key.ToString().ToLowerInvariant() -eq $Operation.ToLowerInvariant())) {
        $entry = $operations[$key]
        $operationKey = $key
        break
      }
    }
  }

  if (-not $entry) {
    throw "Operation '$Operation' is not defined in icon editor dev-mode policy '$($policy.Path)'."
  }

  $versions = @()
  if ($entry.versions) {
    foreach ($value in $entry.versions) {
      if ($null -ne $value) { $versions += [int]$value }
    }
  }

  $bitness = @()
  if ($entry.bitness) {
    foreach ($value in $entry.bitness) {
      if ($null -ne $value) { $bitness += [int]$value }
    }
  }

  return [pscustomobject]@{
    Operation = $operationKey
    Versions  = $versions
    Bitness   = $bitness
    Path      = $policy.Path
  }
}

function Test-IconEditorReliabilityOperation {
  param([string]$Operation)
  if (-not $Operation) { return $false }
  $normalized = $Operation.Trim()
  if ([string]::IsNullOrWhiteSpace($normalized)) { return $false }
  return ($normalized.ToLowerInvariant() -eq 'reliability')
}

function Enable-IconEditorDevelopmentMode {
  param(
    [string]$RepoRoot,
    [string]$IconEditorRoot,
    [int[]]$Versions,
    [int[]]$Bitness,
    [string]$Operation = 'Compare',
    [string]$RunRoot,
    [switch]$AllowForceClose
  )

  if (-not $RepoRoot) {
    $RepoRoot = Resolve-IconEditorRepoRoot
  } else {
    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
  }

  if (-not $IconEditorRoot) {
    $IconEditorRoot = Resolve-IconEditorRoot -RepoRoot $RepoRoot
  } else {
    $IconEditorRoot = (Resolve-Path -LiteralPath $IconEditorRoot).Path
  }

  $actionsRoot = Join-PathSegments @($IconEditorRoot, '.github', 'actions')
  $addTokenScript = Join-PathSegments @($actionsRoot, 'add-token-to-labview', 'AddTokenToLabVIEW.ps1')
  $prepareScript  = Join-PathSegments @($actionsRoot, 'prepare-labview-source', 'Prepare_LabVIEW_source.ps1')

  foreach ($required in @($addTokenScript, $prepareScript)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
      throw "Icon editor dev-mode helper '$required' was not found."
    }
  }

  $targetsOverride = $null
  if (-not $PSBoundParameters.ContainsKey('Versions') -or -not $PSBoundParameters.ContainsKey('Bitness')) {
    try {
      $targetsOverride = Get-IconEditorDevModePolicyEntry -RepoRoot $RepoRoot -Operation $Operation
    } catch {
      $targetsOverride = $null
      if (-not $PSBoundParameters.ContainsKey('Versions') -and -not $PSBoundParameters.ContainsKey('Bitness')) {
        throw
      }
    }
  }

  $defaultTargets = Get-DefaultIconEditorDevModeTargets -Operation $Operation
  [array]$overrideVersions = @()
  [array]$overrideBitness  = @()
  if ($targetsOverride) {
    $overrideVersions = @($targetsOverride.Versions)
    $overrideBitness  = @($targetsOverride.Bitness)
  }
  [array]$effectiveVersions = if ($overrideVersions.Count -gt 0) { $overrideVersions } else { @($defaultTargets.Versions) }
  [array]$effectiveBitness  = if ($overrideBitness.Count -gt 0)  { $overrideBitness }  else { @($defaultTargets.Bitness) }

  [array]$versionList = ConvertTo-IntList -Values $Versions -DefaultValues $effectiveVersions
  [array]$bitnessList = ConvertTo-IntList -Values $Bitness -DefaultValues $effectiveBitness

  if ($versionList.Count -eq 0 -or $bitnessList.Count -eq 0) {
    throw "LabVIEW version/bitness selection resolved to an empty set for operation '$Operation'."
  }

  $preStage = if ($Operation) { "disable-{0}-pre" -f $Operation } else { 'disable-devmode-pre' }
  Invoke-IconEditorRogueCheck -RepoRoot $RepoRoot -Stage $preStage -FailOnRogue -AutoClose -RunRoot $RunRoot -Versions $versionList -Bitness $bitnessList | Out-Null

  $strictReliability = Test-IconEditorReliabilityOperation -Operation $Operation
  if ($strictReliability) {
    Write-Host ("[dev-mode] Reliability policy active for operation '{0}'." -f $Operation) -ForegroundColor DarkGray
  }

  $pluginsPath = Join-PathSegments @($IconEditorRoot, 'resource', 'plugins')
  if (Test-Path -LiteralPath $pluginsPath -PathType Container) {
    Get-ChildItem -LiteralPath $pluginsPath -Filter '*.lvlibp' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
  }

  foreach ($versionValue in $versionList) {
    $versionText = [string]$versionValue
    foreach ($bitnessValue in $bitnessList) {
      $bitnessText = [string]$bitnessValue
      Invoke-LabVIEWPrelaunchGuard `
        -RepoRoot $RepoRoot `
        -Stage ("enable-addtoken-{0}-{1}" -f $versionText, $bitnessText) `
        -Versions @($versionValue) `
        -Bitness @($bitnessValue) `
        -IconEditorRoot $IconEditorRoot `
        -RunRoot $RunRoot `
        -AllowForceClose:$AllowForceClose | Out-Null
      $localhostLibraryPath = Get-IconEditorLocalhostLibraryPath -IconEditorRoot $IconEditorRoot
      $tokenPresent = $false
      try {
        $tokenCheck = Test-IconEditorDevelopmentMode -RepoRoot $RepoRoot -IconEditorRoot $IconEditorRoot -Versions @($versionValue) -Bitness @($bitnessValue)
        if ($tokenCheck -and $tokenCheck.Entries) {
          $tokenPresent = ($tokenCheck.Entries | Where-Object { $_.Present -and $_.ContainsIconEditorPath }).Count -gt 0
        }
      } catch {
        $tokenPresent = $false
      }
      if ($tokenPresent) {
        Write-Host ("Icon editor path already present in Localhost.LibraryPaths for LabVIEW {0} ({1}-bit); skipping add-token stage." -f $versionText, $bitnessText) -ForegroundColor Yellow
      } else {
        Invoke-IconEditorDevModeScript `
          -ScriptPath $addTokenScript `
          -ArgumentList @(
            '-MinimumSupportedLVVersion', $versionText,
            '-SupportedBitness',          $bitnessText,
            '-RelativePath',              $localhostLibraryPath
          ) `
          -RepoRoot $RepoRoot `
          -IconEditorRoot $IconEditorRoot `
          -StageLabel ("enable-addtoken-{0}-{1}" -f $versionText, $bitnessText)
      }

      Invoke-LabVIEWRogueSweep `
        -RepoRoot $RepoRoot `
        -Reason ("enable-addtoken-{0}-{1}" -f $versionText, $bitnessText) `
        -RequireClean:$strictReliability `
        -RunRoot $RunRoot `
        -Versions @($versionValue) `
        -Bitness @($bitnessValue) `
        -ForceTerminateOnFailure:$AllowForceClose | Out-Null

      Invoke-LabVIEWPrelaunchGuard `
        -RepoRoot $RepoRoot `
        -Stage ("enable-prepare-{0}-{1}" -f $versionText, $bitnessText) `
        -Versions @($versionValue) `
        -Bitness @($bitnessValue) `
        -IconEditorRoot $IconEditorRoot `
        -RunRoot $RunRoot `
        -AllowForceClose:$AllowForceClose | Out-Null
      Invoke-IconEditorDevModeScript `
        -ScriptPath $prepareScript `
        -ArgumentList @(
          '-MinimumSupportedLVVersion', $versionText,
          '-SupportedBitness',          $bitnessText,
          '-RelativePath',              $IconEditorRoot,
          '-LabVIEW_Project',         'lv_icon_editor',
          '-Build_Spec',              'Editor Packed Library'
        ) `
        -RepoRoot $RepoRoot `
        -IconEditorRoot $IconEditorRoot `
        -StageLabel ("enable-prepare-{0}-{1}" -f $versionText, $bitnessText)

      Invoke-LabVIEWRogueSweep `
        -RepoRoot $RepoRoot `
        -Reason ("enable-prepare-{0}-{1}" -f $versionText, $bitnessText) `
        -RequireClean:$strictReliability `
        -RunRoot $RunRoot `
        -Versions @($versionValue) `
        -Bitness @($bitnessValue) `
        -ForceTerminateOnFailure:$AllowForceClose | Out-Null

      # Keep LabVIEW running after preparing source; closing is handled elsewhere when needed.
    }
  }

  $verification = Assert-IconEditorDevModeTokenState -RepoRoot $RepoRoot -IconEditorRoot $IconEditorRoot -Versions $versionList -Bitness $bitnessList -ExpectedActive $true
  $state = Set-IconEditorDevModeState -RepoRoot $RepoRoot -Active $true -Source ("Enable-IconEditorDevelopmentMode:{0}" -f $Operation)
  if ($verification) {
    $state | Add-Member -NotePropertyName Verification -NotePropertyValue $verification -Force
  }
  Close-IconEditorLabVIEW `
    -RepoRoot $RepoRoot `
    -IconEditorRoot $IconEditorRoot `
    -Versions $versionList `
    -Bitness $bitnessList `
    -FailOnRogue:$strictReliability `
    -RunRoot $RunRoot
  Invoke-LabVIEWRogueSweep `
    -RepoRoot $RepoRoot `
    -Reason 'enable-close' `
    -RequireClean:$strictReliability `
    -RunRoot $RunRoot `
    -Versions $versionList `
    -Bitness $bitnessList `
    -ForceTerminateOnFailure:$AllowForceClose | Out-Null
  $postStage = if ($Operation) { "devmode-{0}-post" -f $Operation } else { 'devmode-post' }
  Invoke-IconEditorRogueCheck -RepoRoot $RepoRoot -Stage $postStage -AutoClose -FailOnRogue:$strictReliability -RunRoot $RunRoot -Versions $versionList -Bitness $bitnessList | Out-Null
  return $state
}

function Disable-IconEditorDevelopmentMode {
  param(
    [string]$RepoRoot,
    [string]$IconEditorRoot,
    [int[]]$Versions,
    [int[]]$Bitness,
    [string]$Operation = 'Compare',
    [string]$RunRoot,
    [switch]$AllowForceClose
  )

  if (-not $RepoRoot) {
    $RepoRoot = Resolve-IconEditorRepoRoot
  } else {
    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
  }

  if (-not $IconEditorRoot) {
    $IconEditorRoot = Resolve-IconEditorRoot -RepoRoot $RepoRoot
  } else {
    $IconEditorRoot = (Resolve-Path -LiteralPath $IconEditorRoot).Path
  }

  $actionsRoot = Join-PathSegments @($IconEditorRoot, '.github', 'actions')
  $restoreScript = Join-PathSegments @($actionsRoot, 'restore-setup-lv-source', 'RestoreSetupLVSource.ps1')
  $closeScript   = Join-PathSegments @($actionsRoot, 'close-labview', 'Close_LabVIEW.ps1')
  $resetHelper   = Resolve-RepoToolFile -RepoRoot $RepoRoot -RelativeSegments @('icon-editor','Reset-IconEditorWorkspace.ps1')

  foreach ($required in @($restoreScript, $closeScript, $resetHelper)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
      throw "Icon editor dev-mode helper '$required' was not found."
    }
  }

  $targetsOverride = $null
  if (-not $PSBoundParameters.ContainsKey('Versions') -or -not $PSBoundParameters.ContainsKey('Bitness')) {
    try {
      $targetsOverride = Get-IconEditorDevModePolicyEntry -RepoRoot $RepoRoot -Operation $Operation
    } catch {
      $targetsOverride = $null
    }
  }

  $defaultTargets = Get-DefaultIconEditorDevModeTargets -Operation $Operation
  [array]$overrideVersions = @()
  [array]$overrideBitness  = @()
  if ($targetsOverride) {
    $overrideVersions = @($targetsOverride.Versions)
    $overrideBitness  = @($targetsOverride.Bitness)
  }
  [array]$effectiveVersions = if ($overrideVersions.Count -gt 0) { $overrideVersions } else { @($defaultTargets.Versions) }
  [array]$effectiveBitness  = if ($overrideBitness.Count -gt 0)  { $overrideBitness }  else { @($defaultTargets.Bitness) }

  [array]$versionsList = ConvertTo-IntList -Values $Versions -DefaultValues $effectiveVersions
  [array]$bitnessList  = ConvertTo-IntList -Values $Bitness -DefaultValues $effectiveBitness

  if ($versionsList.Count -eq 0) {
    $versionsList = @($effectiveVersions | ForEach-Object { [int]$_ })
  }
  if ($bitnessList.Count -eq 0) {
    $bitnessList = @($effectiveBitness | ForEach-Object { [int]$_ })
  }

  if ($versionsList.Count -eq 0 -or $bitnessList.Count -eq 0) {
    throw "LabVIEW version/bitness selection resolved to an empty set for operation '$Operation'."
  }

  $strictReliability = Test-IconEditorReliabilityOperation -Operation $Operation
  if ($strictReliability) {
    Write-Host ("[dev-mode] Reliability policy active for disable operation '{0}'." -f $Operation) -ForegroundColor DarkGray
  }

  try {
    & $resetHelper `
      -RepoRoot $RepoRoot `
      -IconEditorRoot $IconEditorRoot `
      -Versions $versionsList `
      -Bitness $bitnessList | Out-Null
  } catch {
    throw "Reset-IconEditorWorkspace.ps1 failed: $($_.Exception.Message)"
  }

  $verification = Assert-IconEditorDevModeTokenState -RepoRoot $RepoRoot -IconEditorRoot $IconEditorRoot -Versions $versionsList -Bitness $bitnessList -ExpectedActive $false
  $state = Set-IconEditorDevModeState -RepoRoot $RepoRoot -Active $false -Source ("Disable-IconEditorDevelopmentMode:{0}" -f $Operation)
  if ($verification) {
    $state | Add-Member -NotePropertyName Verification -NotePropertyValue $verification -Force
  }
  Close-IconEditorLabVIEW `
    -RepoRoot $RepoRoot `
    -IconEditorRoot $IconEditorRoot `
    -Versions $versionsList `
    -Bitness $bitnessList `
    -FailOnRogue:$strictReliability `
    -RunRoot $RunRoot
  Invoke-LabVIEWRogueSweep `
    -RepoRoot $RepoRoot `
    -Reason 'disable-close' `
    -RequireClean:$strictReliability `
    -RunRoot $RunRoot `
    -Versions $versionsList `
    -Bitness $bitnessList `
    -ForceTerminateOnFailure:$AllowForceClose | Out-Null
  $postStage = if ($Operation) { "disable-{0}-post" -f $Operation } else { 'disable-devmode-post' }
  Invoke-IconEditorRogueCheck -RepoRoot $RepoRoot -Stage $postStage -AutoClose -FailOnRogue:$strictReliability -RunRoot $RunRoot -Versions $versionsList -Bitness $bitnessList | Out-Null
  return $state
}

function Get-IconEditorDevModeLabVIEWTargets {
  param(
    [string]$RepoRoot,
    [string]$IconEditorRoot,
    [int[]]$Versions = @(2023),
    [int[]]$Bitness = @(32, 64)
  )

  if (-not $RepoRoot) {
    $RepoRoot = Resolve-IconEditorRepoRoot
  } else {
    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
  }

  if (-not $IconEditorRoot) {
    $IconEditorRoot = Resolve-IconEditorRoot -RepoRoot $RepoRoot
  } else {
    $IconEditorRoot = (Resolve-Path -LiteralPath $IconEditorRoot).Path
  }

  Import-Module (Resolve-VendorToolsModulePath -RepoRoot $RepoRoot -Context $Context) -Force

  $versionList = ConvertTo-IntList -Values $Versions -DefaultValues @(2023)
  $bitnessList = ConvertTo-IntList -Values $Bitness -DefaultValues @(32,64)

  $targets = New-Object System.Collections.Generic.List[object]
  foreach ($version in $versionList) {
    foreach ($bit in $bitnessList) {
      $exePath = Find-LabVIEWVersionExePath -Version $version -Bitness $bit
      $iniPath = $null
      $present = $false
      if ($exePath) {
        $present = $true
        $iniPath = Get-LabVIEWIniPath -LabVIEWExePath $exePath
      }
      $targets.Add([pscustomobject]@{
        Version = $version
        Bitness = $bit
        LabVIEWExePath = $exePath
        LabVIEWIniPath = $iniPath
        Present = [bool]$present
        IconEditorRoot = $IconEditorRoot
      }) | Out-Null
    }
  }

  return $targets.ToArray()
}

function Assert-IconEditorDevModeTokenState {
  param(
    [string]$RepoRoot,
    [string]$IconEditorRoot,
    [int[]]$Versions,
    [int[]]$Bitness,
    [bool]$ExpectedActive
  )

  $verification = Test-IconEditorDevelopmentMode -RepoRoot $RepoRoot -IconEditorRoot $IconEditorRoot -Versions $Versions -Bitness $Bitness
  if (-not $verification) { return $null }

  $presentEntries = @($verification.Entries | Where-Object { $_.Present -and $_.LabVIEWIniPath })
  if (-not $presentEntries -or $presentEntries.Count -eq 0) {
    Write-Verbose "Icon editor dev-mode verification: no LabVIEW targets present; skipping token check."
    return $verification
  }

  $violations = if ($ExpectedActive) {
    @($presentEntries | Where-Object { (-not $_.ContainsIconEditorPath) -or ($_.TokenValueEmpty -eq $true) })
  } else {
    @($presentEntries | Where-Object { $_.ContainsIconEditorPath })
  }

  if ($violations -and $violations.Count -gt 0) {
    $expectation = if ($ExpectedActive) { 'include' } else { 'exclude' }
    $details = $violations | ForEach-Object {
      $iniPath = if ($_.LabVIEWIniPath) { $_.LabVIEWIniPath } else { '[ini path unavailable]' }
      $status = if ($_.ContainsIconEditorPath) { 'contains icon-editor path' } else { 'missing icon-editor path' }
      if ($_.TokenValueEmpty -eq $true) {
        $status = 'LocalHost.LibraryPaths empty'
      } elseif ($_.TokenValue) {
        $status = "$status (found: '$($_.TokenValue)')"
      }
      "LabVIEW {0} ({1}-bit) - {2} (ini: {3})" -f $_.Version, $_.Bitness, $status, $iniPath
    }
    $joined = [string]::Join('; ', $details)
    throw "Icon editor dev-mode verification failed: expected LabVIEW to $expectation the icon-editor path. Violations: $joined"
  }

  return $verification
}

function Test-IconEditorDevelopmentMode {
  param(
    [string]$RepoRoot,
    [string]$IconEditorRoot,
    [int[]]$Versions = @(2023),
    [int[]]$Bitness = @(32, 64)
  )

  if (-not $RepoRoot) {
    $RepoRoot = Resolve-IconEditorRepoRoot
  } else {
    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
  }

  if (-not $IconEditorRoot) {
    $IconEditorRoot = Resolve-IconEditorRoot -RepoRoot $RepoRoot
  } else {
    $IconEditorRoot = (Resolve-Path -LiteralPath $IconEditorRoot).Path
  }

  $iconEditorRootLower = $IconEditorRoot.ToLowerInvariant().TrimEnd('\')
  $targets = Get-IconEditorDevModeLabVIEWTargets -RepoRoot $RepoRoot -IconEditorRoot $IconEditorRoot -Versions $Versions -Bitness $Bitness
  $results = New-Object System.Collections.Generic.List[object]

  foreach ($target in $targets) {
    $tokenValue = $null
    $containsIconEditor = $false
    $tokenEmpty = $true
    if ($target.Present -and $target.LabVIEWIniPath -and (Test-Path -LiteralPath $target.LabVIEWIniPath -PathType Leaf)) {
      try {
        $tokenValue = Get-LabVIEWIniValue -Key 'LocalHost.LibraryPaths' -LabVIEWExePath $target.LabVIEWExePath -LabVIEWIniPath $target.LabVIEWIniPath
      } catch {
        $tokenValue = $null
      }
      if ($tokenValue) {
        $tokenEmpty = [string]::IsNullOrWhiteSpace($tokenValue)
        $normalizedValue = ($tokenValue -replace '"', '').Split(';') | ForEach-Object {
          $_.Trim().TrimEnd('\').ToLowerInvariant()
        }
        foreach ($entry in $normalizedValue) {
          if ($entry -eq '') { continue }
          if ($entry -eq $iconEditorRootLower -or $entry.StartsWith($iconEditorRootLower)) {
            $containsIconEditor = $true
            break
          }
        }
      } else {
        $tokenEmpty = $true
      }
    }

    $results.Add([pscustomobject]@{
      Version = $target.Version
      Bitness = $target.Bitness
      LabVIEWExePath = $target.LabVIEWExePath
      LabVIEWIniPath = $target.LabVIEWIniPath
      Present = $target.Present
      TokenValue = $tokenValue
      TokenValueEmpty = $tokenEmpty
      ContainsIconEditorPath = $containsIconEditor
    }) | Out-Null
  }

  $presentEntries = @($results | Where-Object { $_.Present })
  $active = $null
  if ($presentEntries.Count -gt 0) {
    $active = $presentEntries | ForEach-Object { $_.ContainsIconEditorPath } | Where-Object { $_ } | Measure-Object | Select-Object -ExpandProperty Count
    $active = ($active -eq $presentEntries.Count)
  }

  return [pscustomobject]@{
    RepoRoot = $RepoRoot
    IconEditorRoot = $IconEditorRoot
    Active = $active
    Entries = $results
  }
}

function Close-IconEditorLabVIEW {
  param(
    [string]$RepoRoot,
    [string]$IconEditorRoot,
    [int[]]$Versions,
    [int[]]$Bitness,
    [int]$WaitTimeoutSeconds = 30,
    [switch]$FailOnRogue,
    [string]$RunRoot
  )

  $skipWait = $false
  $skipEnv = $env:ICON_EDITOR_SKIP_WAIT_FOR_LABVIEW_EXIT
  if ($skipEnv) {
    $value = $skipEnv.ToString().ToLowerInvariant()
    if ($value -in @('1','true','yes','on')) {
      $skipWait = $true
    }
  }

  if (-not $RepoRoot) {
    $RepoRoot = Resolve-IconEditorRepoRoot
  } else {
    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
  }

  if (-not $IconEditorRoot) {
    $IconEditorRoot = Resolve-IconEditorRoot -RepoRoot $RepoRoot
  } else {
    $IconEditorRoot = (Resolve-Path -LiteralPath $IconEditorRoot).Path
  }

  $actionsRoot = Join-PathSegments @($IconEditorRoot, '.github', 'actions')
  $closeScript = Join-PathSegments @($actionsRoot, 'close-labview', 'Close_LabVIEW.ps1')
  if (-not (Test-Path -LiteralPath $closeScript -PathType Leaf)) {
    Write-Verbose "Close-IconEditorLabVIEW: close script not found at '$closeScript'; skipping graceful shutdown."
    return
  }

  Import-Module (Resolve-VendorToolsModulePath -RepoRoot $RepoRoot -Context $Context) -Force

  $rawVersions = ConvertTo-IntList -Values $Versions -DefaultValues @(2023)
  $rawBitness  = ConvertTo-IntList -Values $Bitness -DefaultValues @(32, 64)
  $versionList = if ($rawVersions) { @($rawVersions) } else { @() }
  $bitnessList = if ($rawBitness) { @($rawBitness) } else { @() }
  $expectedExePaths = New-Object System.Collections.Generic.List[string]

  foreach ($version in $versionList) {
    foreach ($bit in $bitnessList) {
      $attemptArgs = @(
        '-MinimumSupportedLVVersion', [string]$version,
        '-SupportedBitness',          [string]$bit
      )

      $closeSucceeded = $false
      for ($attempt = 1; $attempt -le 2 -and -not $closeSucceeded; $attempt++) {
        try {
          Invoke-IconEditorDevModeScript `
            -ScriptPath $closeScript `
            -ArgumentList $attemptArgs `
            -RepoRoot $RepoRoot `
            -IconEditorRoot $IconEditorRoot
          $closeSucceeded = $true
        } catch {
          $message = $_.Exception.Message
          $transient = $message -match 'Timed out waiting for app to connect to g-cli' -or $message -match 'Failed to close LabVIEW with exit code 1'
          if ($transient -and $attempt -lt 2) {
            Write-Warning ("Close-IconEditorLabVIEW: retrying after g-cli timeout when closing LabVIEW {0} ({1}-bit)." -f $version, $bit)
            Start-Sleep -Seconds 2
            continue
          }
          if ($transient) {
            Write-Warning ("Close-IconEditorLabVIEW: ignoring repeated g-cli timeout when closing LabVIEW {0} ({1}-bit): {2}" -f $version, $bit, $message)
            $closeSucceeded = $true
          } else {
            throw
          }
        }
      }

      $exePath = Find-LabVIEWVersionExePath -Version $version -Bitness $bit
      if ($exePath) {
        $resolvedExe = $null
        try {
          $resolvedExe = (Resolve-Path -LiteralPath $exePath).Path.ToLowerInvariant()
        } catch {
          $resolvedExe = $exePath.ToLowerInvariant()
        }
        if ($resolvedExe -and -not $expectedExePaths.Contains($resolvedExe)) {
          [void]$expectedExePaths.Add($resolvedExe)
        }
      }
    }
  }

  $exeArray = if ($expectedExePaths.Count -gt 0) { $expectedExePaths.ToArray() } else { @() }

  if ($skipWait) {
    Write-Verbose "Close-IconEditorLabVIEW: skipping wait for LabVIEW exit (ICON_EDITOR_SKIP_WAIT_FOR_LABVIEW_EXIT=$skipEnv)."
    return
  }

$settleResult = Wait-IconEditorLabVIEWSettle -ExeCandidates $exeArray -TimeoutSeconds $WaitTimeoutSeconds -Stage 'close-labview'
  if (-not $settleResult.Succeeded) {
    throw "Timed out waiting for LabVIEW to exit after close sequence."
  }

  Invoke-IconEditorRogueCheck -RepoRoot $RepoRoot -Stage 'close-labview' -AutoClose -FailOnRogue:$FailOnRogue -RunRoot $RunRoot | Out-Null
}

function Wait-LabVIEWProcessExit {
  param(
    [string[]]$ExeCandidates,
    [int]$TimeoutSeconds = 30
  )

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  $normalizedCandidates = @()
  if ($ExeCandidates) {
    $normalizedCandidates = $ExeCandidates | Where-Object { $_ } | ForEach-Object { $_.ToLowerInvariant() }
  }

  while ($true) {
    $running = @(Get-Process LabVIEW -ErrorAction SilentlyContinue)
    if (-not $running -or $running.Count -eq 0) {
      return $true
    }

    if ($normalizedCandidates.Length -gt 0) {
      $matching = @()
      foreach ($proc in $running) {
        $procPath = $null
        try {
          $procPath = $proc.Path
        } catch {
          $procPath = $null
        }
        if (-not $procPath) {
          $matching += $proc
          continue
        }
        $procNormalized = $procPath.ToLowerInvariant()
        if ($normalizedCandidates -contains $procNormalized) {
          $matching += $proc
        }
      }
      if ($matching.Count -eq 0) {
        return $true
      }
    } else {
      if ($running.Count -eq 0) {
        return $true
      }
    }

    if ((Get-Date) -ge $deadline) {
      return $false
    }

    Start-Sleep -Milliseconds 500
  }
}

function Wait-IconEditorLabVIEWSettle {
  param(
    [string[]]$ExeCandidates,
    [int]$TimeoutSeconds = 30,
    [int]$ExtraSleepSeconds = 2,
    [string]$Stage = 'labview-settle',
    [switch]$SuppressWarning,
    [int]$FastTimeoutSeconds
  )

  $result = [ordered]@{
    stage = $Stage
    succeeded = $false
    durationSeconds = 0
    timeoutSeconds = $TimeoutSeconds
    extraSleepSeconds = $ExtraSleepSeconds
  }

  $watch = [System.Diagnostics.Stopwatch]::StartNew()
  $settleTimeout = $TimeoutSeconds
  $fastPathTried = $false
  if ($FastTimeoutSeconds -gt 0 -and $FastTimeoutSeconds -lt $TimeoutSeconds) {
    $settleTimeout = $FastTimeoutSeconds
    $fastPathTried = $true
  }

  $ok = Wait-LabVIEWProcessExit -ExeCandidates $ExeCandidates -TimeoutSeconds $settleTimeout
  if (-not $ok -and $fastPathTried) {
    $settleTimeout = $TimeoutSeconds
    $ok = Wait-LabVIEWProcessExit -ExeCandidates $ExeCandidates -TimeoutSeconds $settleTimeout
  }

  if (-not $ok) {
    $result.error = "Timed out waiting for LabVIEW processes to exit."
    $running = @(Get-Process LabVIEW -ErrorAction SilentlyContinue)
    if ($running -and $running.Count -gt 0) {
      $result.runningPids = ($running | Select-Object -ExpandProperty Id)
      if (-not $SuppressWarning) {
        Write-Warning ("{0}: still saw LabVIEW PIDs {1} after {2}s." -f $Stage, ($result.runningPids -join ','), $settleTimeout)
      }
    }
  } else {
    if ($ExtraSleepSeconds -gt 0) {
      Start-Sleep -Seconds $ExtraSleepSeconds
    }
    $result.succeeded = $true
  }

  $watch.Stop()
  $result.durationSeconds = [Math]::Round($watch.Elapsed.TotalSeconds, 2)
  $event = [pscustomobject]$result
  $listVar = Get-Variable -Name IconEditorLabVIEWSettleEvents -Scope Script -ErrorAction SilentlyContinue
  if (-not $listVar -or -not $listVar.Value) {
    $script:IconEditorLabVIEWSettleEvents = New-Object System.Collections.Generic.List[object]
    $listVar = Get-Variable -Name IconEditorLabVIEWSettleEvents -Scope Script -ErrorAction SilentlyContinue
  }
  if ($listVar -and $listVar.Value) {
    $listVar.Value.Add($event) | Out-Null
  }
  return $event
}

function Invoke-LabVIEWPrelaunchGuard {
  param(
    [string]$RepoRoot,
    [string]$Stage = 'labview-prelaunch',
    [int]$SettleTimeoutSeconds = 10,
    [int]$SettleSleepSeconds = 1,
    [int[]]$Versions,
    [int[]]$Bitness,
    [string]$IconEditorRoot,
    [string]$RunRoot,
    [switch]$AllowForceClose
  )

  if (-not $RepoRoot) {
    $RepoRoot = Resolve-IconEditorRepoRoot
  } else {
    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
  }
  $resolvedIconEditorRoot = $IconEditorRoot
  if (-not $resolvedIconEditorRoot) {
    try {
      $resolvedIconEditorRoot = Resolve-IconEditorRoot -RepoRoot $RepoRoot
    } catch {
      $resolvedIconEditorRoot = $null
    }
  }

  Invoke-IconEditorRogueCheck -RepoRoot $RepoRoot -Stage $Stage -AutoClose -RunRoot $RunRoot | Out-Null
  $fastTimeout = [Math]::Min([Math]::Max([Math]::Floor($SettleTimeoutSeconds / 2), 3), $SettleTimeoutSeconds - 1)
  if ($SettleTimeoutSeconds -le 3) { $fastTimeout = 0 }
  $settleResult = Wait-IconEditorLabVIEWSettle `
    -ExeCandidates @() `
    -TimeoutSeconds $SettleTimeoutSeconds `
    -FastTimeoutSeconds $fastTimeout `
    -ExtraSleepSeconds $SettleSleepSeconds `
    -Stage ("{0}-settle" -f $Stage) `
    -SuppressWarning
  if (-not $settleResult.Succeeded) {
    Write-Warning ("{0}: initial settle failed, attempting rogue cleanup and retry." -f $Stage)
    try {
      Invoke-IconEditorRogueCheck -RepoRoot $RepoRoot -Stage ("{0}-rogue-retry" -f $Stage) -AutoClose -RunRoot $RunRoot | Out-Null
    } catch {
      Write-Warning ("{0}: rogue cleanup retry encountered an error: {1}" -f $Stage, $_.Exception.Message)
    }
    if ($Versions -and $Bitness -and $resolvedIconEditorRoot) {
      try {
        Close-IconEditorLabVIEW -RepoRoot $RepoRoot -IconEditorRoot $resolvedIconEditorRoot -Versions $Versions -Bitness $Bitness -RunRoot $RunRoot | Out-Null
      } catch {
        Write-Warning ("{0}: Close-LabVIEW fallback reported: {1}" -f $Stage, $_.Exception.Message)
      }
    }
    $terminated = @()
    $pidsToKill = @()
    if ($settleResult.PSObject.Properties['runningPids'] -and $settleResult.runningPids) {
      $pidsToKill += $settleResult.runningPids
    }
    try {
      $liveLabVIEW = @(Get-Process -Name 'LabVIEW' -ErrorAction SilentlyContinue)
      if ($liveLabVIEW) {
        $pidsToKill += ($liveLabVIEW | Select-Object -ExpandProperty Id)
      }
    } catch {}
    $pidsToKill = @($pidsToKill | Sort-Object -Unique)
    if ($pidsToKill.Count -gt 0 -and $AllowForceClose) {
      foreach ($pid in $pidsToKill) {
        try {
          Stop-Process -Id $pid -Force -ErrorAction Stop
          $terminated += $pid
        } catch {
          Write-Warning ("{0}: failed to terminate LabVIEW PID {1}: {2}" -f $Stage, $pid, $_.Exception.Message)
        }
      }
      if ($terminated.Count -gt 0) {
        Write-Warning ("{0}: forcibly terminated LabVIEW PIDs {1} prior to settle retry." -f $Stage, ($terminated -join ','))
      }
    } elseif ($pidsToKill.Count -gt 0 -and -not $AllowForceClose) {
      Write-Warning ("{0}: force-close disabled; leaving LabVIEW PIDs {1} running for retry. Set DevModeAllowForceClose or LOCALCI_DEV_MODE_FORCE_CLOSE=1 to terminate them automatically." -f $Stage, ($pidsToKill -join ','))
    }
    $retryTimeout = [Math]::Max($SettleTimeoutSeconds * 2, $SettleTimeoutSeconds + 10)
    $settleResult = Wait-IconEditorLabVIEWSettle -ExeCandidates @() -TimeoutSeconds $retryTimeout -ExtraSleepSeconds $SettleSleepSeconds -Stage ("{0}-settle-retry" -f $Stage)
    if (-not $settleResult.Succeeded) {
      throw "Pre-launch settle failed for stage '$Stage'."
    }
  }
  return $settleResult
}

function Get-IconEditorLabVIEWSettleEvents {
  param([switch]$Clear = $true)
  $listVar = Get-Variable -Name IconEditorLabVIEWSettleEvents -Scope Script -ErrorAction SilentlyContinue
  if (-not $listVar -or -not $listVar.Value) { return @() }
  $buffer = $listVar.Value
  $events = $buffer.ToArray()
  if ($Clear) { $buffer.Clear() }
  return $events
}

function Get-IconEditorSettleSummary {
  param([object[]]$Events)

  if (-not $Events -or $Events.Count -eq 0) { return $null }
  $flatEvents = @()
  foreach ($evt in $Events) {
    if (-not $evt) { continue }
    if ($evt -is [System.Array]) {
      foreach ($inner in $evt) {
        if ($inner) { $flatEvents += $inner }
      }
    } else {
      $flatEvents += $evt
    }
  }

  if ($flatEvents.Count -eq 0) { return $null }

  $succeeded = @($flatEvents | Where-Object { $_.Succeeded })
  $failed    = @($flatEvents | Where-Object { -not $_.Succeeded })
  $duration  = 0
  foreach ($evt in $flatEvents) {
    if ($evt.PSObject.Properties['durationSeconds']) {
      $duration += [double]$evt.durationSeconds
    }
  }

  $summary = [ordered]@{
    totalEvents          = $flatEvents.Count
    succeededEvents      = $succeeded.Count
    failedEvents         = $failed.Count
    totalDurationSeconds = [Math]::Round($duration, 2)
  }

  if ($failed.Count -gt 0) {
    $summary.failedStages = ($failed | ForEach-Object { $_.stage } | Where-Object { $_ } | Sort-Object -Unique)
    $summary.failedErrors = ($failed | ForEach-Object { $_.error } | Where-Object { $_ } | Sort-Object -Unique)
  }

  return $summary
}

function Get-IconEditorVerificationSummary {
  param([psobject]$Verification)

  if (-not $Verification) { return $null }

  $entries = @()
  if ($Verification.PSObject.Properties['Entries']) {
    foreach ($entry in $Verification.Entries) {
      if ($entry) { $entries += $entry }
    }
  }

  $presentEntries = @($entries | Where-Object { $_.Present })
  $withIconEditor = @($presentEntries | Where-Object { $_.ContainsIconEditorPath })

  $summary = [ordered]@{
    presentCount            = $presentEntries.Count
    containsIconEditorCount = $withIconEditor.Count
    active                  = $Verification.Active
  }

  if ($presentEntries.Count -gt 0 -and $withIconEditor.Count -lt $presentEntries.Count) {
    $summary.missingTargets = $presentEntries |
      Where-Object { -not $_.ContainsIconEditorPath } |
      ForEach-Object {
        [ordered]@{
          version = $_.Version
          bitness = $_.Bitness
          labviewIniPath = $_.LabVIEWIniPath
        }
      }
  }

  return $summary
}

function Invoke-LabVIEWRogueSweep {
  param(
    [string]$RepoRoot,
    [string]$Reason = 'rogue-sweep',
    [int]$LookBackSeconds = 900,
    [switch]$RequireClean,
    [switch]$InvokeCloseOnDetection = $true,
    [string]$RunRoot,
    [int[]]$Versions,
    [int[]]$Bitness,
    [switch]$ForceTerminateOnFailure
  )

  if (-not $RepoRoot) { return $null }
  $detectScript = Resolve-RepoToolFile -RepoRoot $RepoRoot -RelativeSegments @('Detect-RogueLV.ps1')
  if (-not (Test-Path -LiteralPath $detectScript -PathType Leaf)) { return $null }

  $resultsDir = Join-PathSegments @($RepoRoot, 'tests', 'results')
  if (-not (Test-Path -LiteralPath $resultsDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $resultsDir | Out-Null
  }
  $rogueDir = Join-PathSegments @($resultsDir, '_agent', 'icon-editor', 'rogue-lv')
  if (-not (Test-Path -LiteralPath $rogueDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $rogueDir | Out-Null
  }

  $versionsList = @()
  if ($Versions) { $versionsList = @($Versions | ForEach-Object { [int]$_ }) }
  $bitnessList = @()
  if ($Bitness) { $bitnessList = @($Bitness | ForEach-Object { [int]$_ }) }

  $runDetection = {
    param([string]$Tag)
    $tagLabel = if ($Tag) { $Tag } else { 'rogue' }
    $path = Join-PathSegments @($rogueDir, ("rogue-sweep-{0}-{1}.json" -f $tagLabel, (Get-Date -Format 'yyyyMMddTHHmmssfff')))
    try {
      & $detectScript -ResultsDir $resultsDir -LookBackSeconds $LookBackSeconds -OutputPath $path -Quiet | Out-Null
    } catch {
      Write-Warning ("{0}: rogue sweep failed ({1})." -f $Reason, $_.Exception.Message)
      return $null
    }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    try {
      $payload = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
      Write-Warning ("{0}: unable to parse rogue sweep output ({1})." -f $Reason, $_.Exception.Message)
      return $null
    }
    return [pscustomobject]@{
      path    = $path
      payload = $payload
    }
  }

  $detection = & $runDetection 'initial'
  if (-not $detection) { return $null }
  $outputPath = $detection.path
  $payload = $detection.payload

  $getRogueLists = {
    param([object]$Payload)
    $rogueLabVIEW = @()
    $rogueLVCompare = @()
    if ($Payload -and $Payload.rogue) {
      if ($Payload.rogue.labview) {
        foreach ($pid in $Payload.rogue.labview) {
          if ($null -ne $pid) {
            try { $rogueLabVIEW += [int]$pid } catch {}
          }
        }
      }
      if ($Payload.rogue.lvcompare) {
        foreach ($pid in $Payload.rogue.lvcompare) {
          if ($null -ne $pid) {
            try { $rogueLVCompare += [int]$pid } catch {}
          }
        }
      }
    }
    return ,@($rogueLabVIEW, $rogueLVCompare)
  }

  $lists = & $getRogueLists -Payload $payload
  $rogueLabVIEW = $lists[0]
  $rogueLVCompare = $lists[1]

  if ($rogueLabVIEW.Count -gt 0 -and $InvokeCloseOnDetection) {
    try {
      Invoke-IconEditorRogueCheck -RepoRoot $RepoRoot -Stage ("{0}-rogue" -f $Reason) -AutoClose -RunRoot $RunRoot -Versions $versionsList -Bitness $bitnessList | Out-Null
    } catch {
      Write-Warning ("{0}: automatic Close-LabVIEW attempt failed ({1})." -f $Reason, $_.Exception.Message)
    }
    $postDetection = & $runDetection 'post'
    if ($postDetection) {
      $outputPath = $postDetection.path
      $payload = $postDetection.payload
      $lists = & $getRogueLists -Payload $payload
      $rogueLabVIEW = $lists[0]
      $rogueLVCompare = $lists[1]
    }
  }

  if ($rogueLabVIEW.Count -gt 0 -and $ForceTerminateOnFailure) {
    Write-Warning ("{0}: force-terminating rogue LabVIEW PIDs {1}." -f $Reason, ($rogueLabVIEW -join ','))
    foreach ($pid in $rogueLabVIEW) {
      try {
        Stop-Process -Id $pid -Force -ErrorAction Stop
      } catch {
        Write-Warning ("{0}: failed to terminate PID {1}: {2}" -f $Reason, $pid, $_.Exception.Message)
      }
    }
  }

  if ($rogueLabVIEW.Count -gt 0 -and $RequireClean) {
    throw "Rogue LabVIEW processes detected during stage '{0}'. See {1} for details." -f $Reason, $outputPath
  }

  return [pscustomobject]@{
    reason = $Reason
    path = $outputPath
    rogueLabVIEW = $rogueLabVIEW
    rogueLVCompare = $rogueLVCompare
  }
}

function Initialize-IconEditorDevModeTelemetry {
  param(
    [ValidateSet('enable','disable')][string]$Mode,
    [string]$RepoRoot,
    [string]$IconEditorRoot,
    [int[]]$Versions,
    [int[]]$Bitness,
    [string]$Operation,
    [string]$ResultsDir
  )

  if (-not $ResultsDir) {
    $ResultsDir = if ($RepoRoot) { Join-PathSegments @($RepoRoot, 'tests', 'results') } else { 'tests/results' }
  }
  if (-not (Test-Path -LiteralPath $ResultsDir -PathType Container)) {
    try { New-Item -ItemType Directory -Force -Path $ResultsDir | Out-Null } catch {}
  }

  $devModeRunDir = Join-PathSegments @($ResultsDir, '_agent', 'icon-editor', 'dev-mode-run')
  if (-not (Test-Path -LiteralPath $devModeRunDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $devModeRunDir | Out-Null
  }

  $scriptStart = Get-Date
  $timestamp = Get-Date -Format 'yyyyMMddTHHmmssfff'
  $labelPrefix = if ($Mode -eq 'enable') { 'dev-mode-on-' } else { 'dev-mode-off-' }
  $telemetryLabel = "{0}{1}" -f $labelPrefix, $timestamp
  $telemetryPath = Join-PathSegments @($devModeRunDir, "dev-mode-run-$timestamp.json")
  $telemetryLatestPath = Join-PathSegments @($devModeRunDir, 'latest-run.json')

  $agentWaitAvailable = $false
  if ($RepoRoot) {
    $agentWaitPath = Resolve-RepoToolFile -RepoRoot $RepoRoot -RelativeSegments @('Agent-Wait.ps1')
    if (Test-Path -LiteralPath $agentWaitPath -PathType Leaf) {
      try {
        . $agentWaitPath
        $agentWaitAvailable = $true
      } catch {
        Write-Verbose ("Initialize-IconEditorDevModeTelemetry: failed to import Agent-Wait.ps1: {0}" -f $_.Exception.Message)
      }
    }
  }

  $context = [ordered]@{
    Mode = $Mode
    RepoRoot = $RepoRoot
    IconEditorRoot = $IconEditorRoot
    ResultsDir = $ResultsDir
    DevModeRunDir = $devModeRunDir
    TelemetryPath = $telemetryPath
    TelemetryLatestPath = $telemetryLatestPath
    TelemetryLabel = $telemetryLabel
    ScriptStart = $scriptStart
    TelemetrySaved = $false
    AgentWaitAvailable = $agentWaitAvailable
    Stages = New-Object System.Collections.Generic.List[object]
  }

  $context.Telemetry = [ordered]@{
    schema = 'icon-editor/dev-mode-run@v1'
    label = $telemetryLabel
    mode = $Mode
    operation = $Operation
    requestedVersions = $Versions
    requestedBitness = $Bitness
    repoRoot = $RepoRoot
    iconEditorRoot = $IconEditorRoot
    startedAt = $scriptStart.ToString('o')
    status = 'pending'
  }

  return [pscustomobject]$context
}

function Invoke-IconEditorTelemetryStage {
  param(
    [Parameter(Mandatory)][psobject]$Context,
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][ScriptBlock]$Action,
    [int]$ExpectedSeconds = 120
  )

  if (-not $Context) {
    throw "Invoke-IconEditorTelemetryStage requires a telemetry context."
  }

  $stage = [ordered]@{
    name = $Name
    startedAt = (Get-Date).ToString('o')
    status = 'pending'
  }
  $watch = [System.Diagnostics.Stopwatch]::StartNew()
  $waitId = "devmode-{0}-{1}" -f $Name, $Context.TelemetryLabel
  if ($Context.AgentWaitAvailable) {
    try {
      Start-AgentWait -Reason ("dev-mode:{0}" -f $Name) -ExpectedSeconds $ExpectedSeconds -ResultsDir $Context.ResultsDir -Id $waitId | Out-Null
    } catch {
      Write-Verbose ("Invoke-IconEditorTelemetryStage: failed to start wait tracking for {0}: {1}" -f $Name, $_.Exception.Message)
    }
  }

  try {
    $result = & $Action $stage
    if ($stage.status -eq 'pending') { $stage.status = 'ok' }
    return $result
  } catch {
    $stage.status = 'failed'
    $stage.error = $_.Exception.Message
    throw
  } finally {
    $watch.Stop()
    $stage.endedAt = (Get-Date).ToString('o')
    $stage.durationSeconds = [Math]::Round($watch.Elapsed.TotalSeconds, 2)
    if ($Context.AgentWaitAvailable) {
      try { End-AgentWait -ResultsDir $Context.ResultsDir -Id $waitId | Out-Null } catch {}
    }
    $null = $Context.Stages.Add($stage)
  }
}

function Complete-IconEditorDevModeTelemetry {
  param(
    [Parameter(Mandatory)][psobject]$Context,
    [string]$Status,
    [object]$State,
    [string]$Error
  )

  if (-not $Context) {
    throw "Complete-IconEditorDevModeTelemetry requires a telemetry context."
  }
  if ($Context.TelemetrySaved) { return }

  $completed = Get-Date
  if ($Status) { $Context.Telemetry.status = $Status }
  if ($State) {
    if ($State.PSObject.Properties['Path']) { $Context.Telemetry.statePath = $State.Path }
    if ($State.PSObject.Properties['UpdatedAt']) { $Context.Telemetry.updatedAt = $State.UpdatedAt }
    if ($State.PSObject.Properties['Verification']) {
      $Context.Telemetry.verification = $State.Verification
      $verificationSummary = Get-IconEditorVerificationSummary -Verification $State.Verification
      if ($verificationSummary) {
        $Context.Telemetry.verificationSummary = $verificationSummary
      }
    }
  }
  if ($Error) { $Context.Telemetry.error = $Error }

  $Context.Telemetry.completedAt = $completed.ToString('o')
  $Context.Telemetry.durationSeconds = [Math]::Round(($completed - $Context.ScriptStart).TotalSeconds, 2)
  $Context.Telemetry.stages = $Context.Stages.ToArray()

  $allSettleEvents = @()
  foreach ($stageRecord in $Context.Telemetry.stages) {
    if ($stageRecord -and $stageRecord.PSObject.Properties['settleEvents']) {
      $allSettleEvents += $stageRecord.settleEvents
    }
  }
  if ($allSettleEvents.Count -gt 0) {
    $settleSummary = Get-IconEditorSettleSummary -Events $allSettleEvents
    if ($settleSummary) {
      $Context.Telemetry.settleSummary = $settleSummary
      if ($settleSummary.PSObject.Properties['totalDurationSeconds']) {
        $Context.Telemetry.settleSeconds = $settleSummary.totalDurationSeconds
      }
    }
  } elseif ($Context.Telemetry.PSObject.Properties['settleSeconds']) {
    $Context.Telemetry.PSObject.Properties.Remove('settleSeconds') | Out-Null
  }

  $json = $Context.Telemetry | ConvertTo-Json -Depth 7
  $json | Set-Content -LiteralPath $Context.TelemetryPath -Encoding utf8
  $json | Set-Content -LiteralPath $Context.TelemetryLatestPath -Encoding utf8
  $Context.TelemetrySaved = $true
}

Export-ModuleMember -Function `
  Resolve-IconEditorRepoRoot, `
  Resolve-IconEditorRoot, `
  Join-PathSegments, `
  Get-IconEditorLocalhostLibraryPath, `
  Get-IconEditorDevModeStatePath, `
  Get-IconEditorDevModeState, `
  Set-IconEditorDevModeState, `
  Invoke-IconEditorRogueCheck, `
  Invoke-IconEditorDevModeScript, `
  Enable-IconEditorDevelopmentMode, `
  Disable-IconEditorDevelopmentMode, `
  Get-IconEditorDevModePolicyPath, `
  Get-IconEditorDevModePolicy, `
  Get-IconEditorDevModePolicyEntry, `
  Get-IconEditorDevModeLabVIEWTargets, `
  Assert-IconEditorDevModeTokenState, `
  Test-IconEditorDevelopmentMode, `
  Wait-IconEditorLabVIEWSettle, `
  Invoke-LabVIEWPrelaunchGuard, `
  Get-IconEditorLabVIEWSettleEvents, `
  Get-IconEditorSettleSummary, `
  Get-IconEditorVerificationSummary, `
  Invoke-LabVIEWRogueSweep, `
  Initialize-IconEditorDevModeTelemetry, `
  Invoke-IconEditorTelemetryStage, `
  Complete-IconEditorDevModeTelemetry
if (-not (Get-Variable -Name IconEditorLabVIEWSettleEvents -Scope Script -ErrorAction SilentlyContinue)) {
  $script:IconEditorLabVIEWSettleEvents = New-Object System.Collections.Generic.List[object]
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

