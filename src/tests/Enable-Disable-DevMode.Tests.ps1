
Describe 'Enable/Disable dev mode scripts' -Tag 'IconEditor','DevMode','Scripts' {
    BeforeAll {
        $script:repoRootActual = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        $script:enableScript = Join-Path $script:repoRootActual 'tools/icon-editor/Enable-DevMode.ps1'
        $script:disableScript = Join-Path $script:repoRootActual 'tools/icon-editor/Disable-DevMode.ps1'
        Test-Path -LiteralPath $script:enableScript | Should -BeTrue
        Test-Path -LiteralPath $script:disableScript | Should -BeTrue
    }

    BeforeEach {
        $env:ICON_EDITOR_SKIP_WAIT_FOR_LABVIEW_EXIT = '1'
    }

    AfterEach {
        Remove-Item Env:ICON_EDITOR_DEV_MODE_POLICY_PATH -ErrorAction SilentlyContinue
        Remove-Item Env:GCLI_EXE_PATH -ErrorAction SilentlyContinue
        if ($script:StubCliPath -and (Test-Path -LiteralPath $script:StubCliPath)) {
            Remove-Item -LiteralPath $script:StubCliPath -Force -ErrorAction SilentlyContinue
        }
        Remove-Item Env:ICON_EDITOR_SKIP_WAIT_FOR_LABVIEW_EXIT -ErrorAction SilentlyContinue
    }

    function Script:Initialize-DevModeStubRepo {
        param([string]$Name = 'devmode-repo')

        $repoRoot = Join-Path $TestDrive $Name
        $iconRoot = Join-Path $repoRoot 'vendor' 'icon-editor'
        $actionsRoot = Join-Path $iconRoot '.github' 'actions'
        $addTokenDir = Join-Path $actionsRoot 'add-token-to-labview'
        $prepareDir  = Join-Path $actionsRoot 'prepare-labview-source'
        $closeDir    = Join-Path $actionsRoot 'close-labview'
        $restoreDir  = Join-Path $actionsRoot 'restore-setup-lv-source'
        $toolsDir    = Join-Path $repoRoot 'tools'
        $toolsIconDir = Join-Path $toolsDir 'icon-editor'
        $labviewRoot = Join-Path $repoRoot 'labview'

        New-Item -ItemType Directory -Path $addTokenDir,$prepareDir,$closeDir,$restoreDir,$toolsDir,$toolsIconDir,$iconRoot,$labviewRoot -Force | Out-Null

        $versionsToStub = @(2025, 2026)
        $bitnessToStub = @(32, 64)
        $labviewDirMap = @{}
        $labviewIniMap = @{}
        foreach ($version in $versionsToStub) {
            foreach ($bit in $bitnessToStub) {
                $comboDir = Join-Path $labviewRoot ("{0}-{1}" -f $version, $bit)
                New-Item -ItemType Directory -Path $comboDir -Force | Out-Null
                Set-Content -LiteralPath (Join-Path $comboDir 'LabVIEW.exe') -Value '' -Encoding utf8
                $iniPath = Join-Path $comboDir 'LabVIEW.ini'
                Set-Content -LiteralPath $iniPath -Value @(
                    '[LabVIEW]'
                    'server.tcp.enabled=1'
                    'LocalHost.LibraryPaths='
                ) -Encoding utf8
                $key = "{0}-{1}" -f $version, $bit
                $labviewDirMap[$key] = $comboDir
                $labviewIniMap[$key] = $iniPath
            }
        }

        $gCliDir      = Join-Path $repoRoot 'fake-g-cli' 'bin'
        $gCliExePath  = Join-Path $gCliDir 'g-cli.exe'
        $gCliStubPath = Join-Path $repoRoot 'fake-g-cli' 'g-cli.ps1'
        New-Item -ItemType Directory -Path $gCliDir -Force | Out-Null
        New-Item -ItemType File -Path $gCliExePath -Value '' -Force | Out-Null

        $mapLines = $labviewDirMap.GetEnumerator() | Sort-Object Key | ForEach-Object { "    '{0}' = '{1}'" -f $_.Key, $_.Value }
        $labviewMapLiteral = if ($mapLines) { [string]::Join([Environment]::NewLine, $mapLines) } else { "    # no stub LabVIEW directories" }

$vendorTemplate = @'
$script:StubLabViewDirectories = @{
__LABVIEW_MAP__
}

function Resolve-GCliPath {
    return '__GCLI_PATH__'
}

function Find-LabVIEWVersionExePath {
    param([int]$Version, [int]$Bitness)
    $key = "{0}-{1}" -f $Version, $Bitness
    if ($script:StubLabViewDirectories.ContainsKey($key)) {
        $exe = Join-Path $script:StubLabViewDirectories[$key] 'LabVIEW.exe'
        if (Test-Path -LiteralPath $exe -PathType Leaf) {
            return $exe
        }
    }
    return $null
}

function Get-LabVIEWIniPath {
    param([string]$LabVIEWExePath)
    if ([string]::IsNullOrWhiteSpace($LabVIEWExePath)) { return $null }
    $candidate = Join-Path (Split-Path -Parent $LabVIEWExePath) 'LabVIEW.ini'
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        return $candidate
    }
    return $null
}

function Get-LabVIEWIniValue {
    param(
        [Parameter(Mandatory = $true)][string]$Key,
        [string]$LabVIEWIniPath,
        [string]$LabVIEWExePath
    )

    if (-not $LabVIEWIniPath) {
        $LabVIEWIniPath = Get-LabVIEWIniPath -LabVIEWExePath $LabVIEWExePath
    }
    if (-not $LabVIEWIniPath -or -not (Test-Path -LiteralPath $LabVIEWIniPath -PathType Leaf)) {
        return $null
    }

    try {
        foreach ($line in (Get-Content -LiteralPath $LabVIEWIniPath)) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            if ($line -match '^\s*[#;]') { continue }
            $parts = $line -split '=', 2
            if ($parts.Count -ne 2) { continue }
            if ($parts[0].Trim() -ieq $Key) {
                return $parts[1].Trim()
            }
        }
    } catch {}

    return $null
}

Export-ModuleMember -Function Resolve-GCliPath, Find-LabVIEWVersionExePath, Get-LabVIEWIniPath, Get-LabVIEWIniValue
'@
        $vendorContent = $vendorTemplate.Replace('__LABVIEW_MAP__', $labviewMapLiteral).Replace('__GCLI_PATH__', $gCliStubPath)
        Set-Content -LiteralPath (Join-Path $toolsDir 'VendorTools.psm1') -Encoding utf8 -Value $vendorContent

@'
[CmdletBinding()]
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)
exit 0
'@ | Set-Content -LiteralPath $gCliStubPath -Encoding utf8
        $env:GCLI_EXE_PATH = $gCliStubPath
        Set-Variable -Scope Script -Name StubCliPath -Value $gCliStubPath

$addTokenTemplate = @'
[CmdletBinding()]
param(
  [string]$MinimumSupportedLVVersion,
  [string]$SupportedBitness,
  [string]$IconEditorRoot,
  [string]$RelativePath,
  [Parameter(ValueFromRemainingArguments=$true)][string[]]$Extra
)

function Get-StubRepoRoot {
  param([string]$IconEditorRoot, [string]$RelativePath)
  if ($IconEditorRoot) { return (Split-Path -Parent (Split-Path -Parent $IconEditorRoot)) }
  if ($RelativePath) { return (Split-Path -Parent (Split-Path -Parent $RelativePath)) }
  return '__REPO_ROOT__'
}

function Update-StubIniEntry {
  param(
    [string]$IniPath,
    [string]$Target,
    [switch]$Remove
  )

  if (-not $IniPath -or -not (Test-Path -LiteralPath $IniPath -PathType Leaf)) { return }

  $normalize = {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    return $Value.Trim().TrimEnd('\').ToLowerInvariant()
  }

  $lines = @(Get-Content -LiteralPath $IniPath)
  if ($lines.Count -eq 0) { $lines = @('LocalHost.LibraryPaths=') }
  $key = 'LocalHost.LibraryPaths'
  $index = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*LocalHost\.LibraryPaths\s*=') { $index = $i; break }
  }

  if ($index -ge 0) {
    $raw = ($lines[$index] -split '=', 2)[1]
    $entries = @()
    if ($raw) {
      $entries = ($raw -split ';') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() }
    }
    $normalizedTarget = & $normalize $Target
    if ($Remove) {
      $entries = $entries | Where-Object { (& $normalize $_) -ne $normalizedTarget }
    } elseif (($entries | Where-Object { (& $normalize $_) -eq $normalizedTarget }).Count -eq 0) {
      $entries += $Target
    }
    $entries = @($entries)
    $lines[$index] = "$key=$([string]::Join(';',$entries))"
  } elseif (-not $Remove) {
    $lines += "$key=$Target"
  }

  Set-Content -LiteralPath $IniPath -Value $lines -Encoding utf8
}

$targetRoot = if ($IconEditorRoot) { $IconEditorRoot } elseif ($RelativePath) { $RelativePath } else { $null }
if (-not $targetRoot) { return }

$repoRoot = Get-StubRepoRoot -IconEditorRoot $IconEditorRoot -RelativePath $RelativePath
$comboDir = Join-Path (Join-Path $repoRoot 'labview') ("{0}-{1}" -f $MinimumSupportedLVVersion, $SupportedBitness)
$iniPath = Join-Path $comboDir 'LabVIEW.ini'

Update-StubIniEntry -IniPath $iniPath -Target $targetRoot
"dev-mode:on-$SupportedBitness" | Set-Content -LiteralPath (Join-Path $targetRoot 'dev-mode.txt') -Encoding utf8
'@
        $addTokenContent = $addTokenTemplate.Replace('__REPO_ROOT__', $repoRoot)
        Set-Content -LiteralPath (Join-Path $addTokenDir 'AddTokenToLabVIEW.ps1') -Encoding utf8 -Value $addTokenContent

        @'
[CmdletBinding()]
param(
  [string]$MinimumSupportedLVVersion,
  [string]$SupportedBitness,
  [string]$IconEditorRoot,
  [string]$RelativePath,
  [string]$LabVIEW_Project,
  [string]$Build_Spec,
  [Parameter(ValueFromRemainingArguments=$true)][string[]]$Extra
)
 $targetRoot = if ($IconEditorRoot) { $IconEditorRoot } elseif ($RelativePath) { $RelativePath } else { $null }
if ($targetRoot) {
  $marker = Join-Path $targetRoot ("prepare-{0}.log" -f $SupportedBitness)
  "prepare:$SupportedBitness" | Set-Content -LiteralPath $marker -Encoding utf8
}
'@ | Set-Content -LiteralPath (Join-Path $prepareDir 'Prepare_LabVIEW_source.ps1') -Encoding utf8

        @'
[CmdletBinding()]
param(
  [string]$MinimumSupportedLVVersion,
  [string]$SupportedBitness
)
'@ | Set-Content -LiteralPath (Join-Path $closeDir 'Close_LabVIEW.ps1') -Encoding utf8

$restoreTemplate = @'
[CmdletBinding()]
param(
  [string]$MinimumSupportedLVVersion,
  [string]$SupportedBitness,
  [string]$IconEditorRoot,
  [string]$LabVIEW_Project,
  [string]$Build_Spec,
  [string]$RelativePath,
  [Parameter(ValueFromRemainingArguments=$true)][string[]]$Extra
)

function Get-StubRepoRoot {
  param([string]$IconEditorRoot, [string]$RelativePath)
  if ($IconEditorRoot) { return (Split-Path -Parent (Split-Path -Parent $IconEditorRoot)) }
  if ($RelativePath) { return (Split-Path -Parent (Split-Path -Parent $RelativePath)) }
  return '__REPO_ROOT__'
}

function Update-StubIniEntry {
  param([string]$IniPath,[string]$Target,[switch]$Remove)
  if (-not $IniPath -or -not (Test-Path -LiteralPath $IniPath -PathType Leaf)) { return }
  $normalize = {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    return $Value.Trim().TrimEnd('\').ToLowerInvariant()
  }
  $lines = @(Get-Content -LiteralPath $IniPath)
  $key = 'LocalHost.LibraryPaths'
  $index = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*LocalHost\.LibraryPaths\s*=') { $index = $i; break }
  }
  if ($index -ge 0) {
    $raw = ($lines[$index] -split '=',2)[1]
    $entries = @()
    if ($raw) {
      $entries = ($raw -split ';') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() }
    }
    $normalizedTarget = & $normalize $Target
    $entries = $entries | Where-Object { (& $normalize $_) -ne $normalizedTarget }
    $entries = @($entries)
    $lines[$index] = "$key=$([string]::Join(';',$entries))"
  }
  Set-Content -LiteralPath $IniPath -Value $lines -Encoding utf8
}

$targetRoot = if ($IconEditorRoot) { $IconEditorRoot } elseif ($RelativePath) { $RelativePath } else { $null }
if (-not $targetRoot) { return }
$repoRoot = Get-StubRepoRoot -IconEditorRoot $IconEditorRoot -RelativePath $RelativePath
$comboDir = Join-Path (Join-Path $repoRoot 'labview') ("{0}-{1}" -f $MinimumSupportedLVVersion, $SupportedBitness)
$iniPath = Join-Path $comboDir 'LabVIEW.ini'

Update-StubIniEntry -IniPath $iniPath -Target $targetRoot -Remove
"dev-mode:off-$SupportedBitness" | Set-Content -LiteralPath (Join-Path $targetRoot 'dev-mode.txt') -Encoding utf8
'@
        $restoreContent = $restoreTemplate.Replace('__REPO_ROOT__', $repoRoot)
        Set-Content -LiteralPath (Join-Path $restoreDir 'RestoreSetupLVSource.ps1') -Encoding utf8 -Value $restoreContent

$resetTemplate = @'
[CmdletBinding()]
param(
  [string]$RepoRoot,
  [string]$IconEditorRoot,
  [int[]]$Versions,
  [int[]]$Bitness,
  [switch]$SkipClose
)

function Get-StubRepoRoot {
  param([string]$RepoRoot,[string]$IconEditorRoot)
  if ($RepoRoot) { return $RepoRoot }
  if ($IconEditorRoot) { return (Split-Path -Parent (Split-Path -Parent $IconEditorRoot)) }
  return '__REPO_ROOT__'
}

function Update-StubIniEntry {
  param([string]$IniPath,[string]$Target,[switch]$Remove)
  if (-not $IniPath -or -not (Test-Path -LiteralPath $IniPath -PathType Leaf)) { return }
  $normalize = {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    return $Value.Trim().TrimEnd('\').ToLowerInvariant()
  }
  $lines = @(Get-Content -LiteralPath $IniPath)
  $key = 'LocalHost.LibraryPaths'
  $index = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*LocalHost\.LibraryPaths\s*=') { $index = $i; break }
  }
  if ($index -ge 0) {
    $raw = ($lines[$index] -split '=',2)[1]
    $entries = @()
    if ($raw) {
      $entries = ($raw -split ';') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() }
    }
    $normalizedTarget = & $normalize $Target
    $entries = $entries | Where-Object { (& $normalize $_) -ne $normalizedTarget }
    $entries = @($entries)
    $lines[$index] = "$key=$([string]::Join(';',$entries))"
  }
  Set-Content -LiteralPath $IniPath -Value $lines -Encoding utf8
}

$targetRoot = if ($IconEditorRoot) { $IconEditorRoot } else { $null }
if (-not $targetRoot) { return }
$resolvedRepo = Get-StubRepoRoot -RepoRoot $RepoRoot -IconEditorRoot $IconEditorRoot

if (-not $Versions -or $Versions.Count -eq 0) { $Versions = @(2025) }
if (-not $Bitness -or $Bitness.Count -eq 0) { $Bitness = @(64) }

foreach ($version in $Versions) {
  foreach ($bit in $Bitness) {
    $comboDir = Join-Path (Join-Path $resolvedRepo 'labview') ("{0}-{1}" -f $version, $bit)
    $iniPath = Join-Path $comboDir 'LabVIEW.ini'
    Update-StubIniEntry -IniPath $iniPath -Target $targetRoot -Remove
    "dev-mode:off-$bit" | Set-Content -LiteralPath (Join-Path $targetRoot 'dev-mode.txt') -Encoding utf8
  }
}
'@
        $resetContent = $resetTemplate.Replace('__REPO_ROOT__', $repoRoot)
        Set-Content -LiteralPath (Join-Path $toolsIconDir 'Reset-IconEditorWorkspace.ps1') -Encoding utf8 -Value $resetContent

        return [pscustomobject]@{
            RepoRoot       = $repoRoot
            IconEditorRoot = $iconRoot
            LabVIEWIniMap  = $labviewIniMap
        }
    }

    It 'enables dev mode via wrapper script' {
        $stub = Initialize-DevModeStubRepo -Name 'enable-script'

        $result = & $script:enableScript `
            -RepoRoot $stub.RepoRoot `
            -IconEditorRoot $stub.IconEditorRoot `
            -Versions 2026 `
            -Bitness 64

        $result.Active | Should -BeTrue
        (Get-Content -LiteralPath (Join-Path $stub.IconEditorRoot 'dev-mode.txt') -Raw).Trim() | Should -Be 'dev-mode:on-64'
        Test-Path -LiteralPath $result.Path | Should -BeTrue
    }

    It 'disables dev mode via wrapper script after enabling' {
        $stub = Initialize-DevModeStubRepo -Name 'disable-script'

        & $script:enableScript `
            -RepoRoot $stub.RepoRoot `
            -IconEditorRoot $stub.IconEditorRoot `
            -Versions 2026 `
            -Bitness 64 | Out-Null

        $result = & $script:disableScript `
            -RepoRoot $stub.RepoRoot `
            -IconEditorRoot $stub.IconEditorRoot `
            -Versions 2026 `
            -Bitness 64

        $result.Active | Should -BeFalse
        (Get-Content -LiteralPath (Join-Path $stub.IconEditorRoot 'dev-mode.txt') -Raw).Trim() | Should -Be 'dev-mode:off-64'
    }

    It 'updates LocalHost.LibraryPaths in the LabVIEW ini when toggling dev mode' {
        $stub = Initialize-DevModeStubRepo -Name 'ini-track'
        $comboKey = '2026-64'
        $iniPath = $stub.LabVIEWIniMap[$comboKey]
        Test-Path -LiteralPath $iniPath | Should -BeTrue

        $normalizePath = {
            param([string]$Value)
            if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
            return $Value.Trim().TrimEnd('\').ToLowerInvariant()
        }

        $getIniEntries = {
            param([string]$Path)
            $line = (Get-Content -LiteralPath $Path | Where-Object { $_ -match '^\s*LocalHost\.LibraryPaths\s*=' } | Select-Object -Last 1)
            if (-not $line) { return @() }
            $value = ($line -split '=', 2)[1]
            return ($value -split ';') | ForEach-Object {
                if ([string]::IsNullOrWhiteSpace($_)) { return }
                $_.Trim().TrimEnd('\')
            }
        }

        $normalizedIconRoot = & $normalizePath $stub.IconEditorRoot
        $before = (& $getIniEntries $iniPath) | ForEach-Object { & $normalizePath $_ }
        $before | Should -Not -Contain $normalizedIconRoot

        & $script:enableScript `
            -RepoRoot $stub.RepoRoot `
            -IconEditorRoot $stub.IconEditorRoot `
            -Versions 2026 `
            -Bitness 64 | Out-Null

        $afterEnable = (& $getIniEntries $iniPath) | ForEach-Object { & $normalizePath $_ }
        $afterEnable | Should -Contain $normalizedIconRoot

        & $script:disableScript `
            -RepoRoot $stub.RepoRoot `
            -IconEditorRoot $stub.IconEditorRoot `
            -Versions 2026 `
            -Bitness 64 | Out-Null

        $afterDisable = (& $getIniEntries $iniPath) | ForEach-Object { & $normalizePath $_ }
        $afterDisable | Should -Not -Contain $normalizedIconRoot
    }

    It 'uses policy defaults when invoking enable wrapper with operation' {
        $stub = Initialize-DevModeStubRepo -Name 'enable-policy'

        $policyDir = Join-Path $stub.RepoRoot 'configs' 'icon-editor'
        New-Item -ItemType Directory -Path $policyDir -Force | Out-Null
        $policyPath = Join-Path $policyDir 'dev-mode-targets.json'
@'
{
  "schema": "icon-editor/dev-mode-targets@v1",
  "operations": {
    "Compare": {
      "versions": [2025],
      "bitness": [64]
    }
  }
}
'@ | Set-Content -LiteralPath $policyPath -Encoding utf8
        $env:ICON_EDITOR_DEV_MODE_POLICY_PATH = $policyPath

        $state = & $script:enableScript `
            -RepoRoot $stub.RepoRoot `
            -IconEditorRoot $stub.IconEditorRoot `
            -Operation 'Compare'

        $state.Active | Should -BeTrue
        $state.Source | Should -Be 'Enable-IconEditorDevelopmentMode:Compare'
        (Get-Content -LiteralPath (Join-Path $stub.IconEditorRoot 'dev-mode.txt') -Raw).Trim() | Should -Be 'dev-mode:on-64'

        $disableState = & $script:disableScript `
            -RepoRoot $stub.RepoRoot `
            -IconEditorRoot $stub.IconEditorRoot `
            -Operation 'Compare'
        $disableState.Active | Should -BeFalse
        (Get-Content -LiteralPath (Join-Path $stub.IconEditorRoot 'dev-mode.txt') -Raw).Trim() | Should -Be 'dev-mode:off-64'
    }

    It 'throws when enable wrapper is missing helper scripts' {
        $stub = Initialize-DevModeStubRepo -Name 'enable-missing'
        Remove-Item -LiteralPath (Join-Path $stub.IconEditorRoot '.github/actions/add-token-to-labview/AddTokenToLabVIEW.ps1') -Force

        $threw = $false
        $exception = $null
        try {
            & $script:enableScript `
                -RepoRoot $stub.RepoRoot `
                -IconEditorRoot $stub.IconEditorRoot `
                -Versions 2026 `
                -Bitness 64
        } catch {
            $threw = $true
            $exception = $_.Exception
        }
        $threw | Should -BeTrue
        $exception.Message | Should -Match 'Icon editor dev-mode helper'
    }

    It 'throws when disable wrapper is missing helper scripts' {
        $stub = Initialize-DevModeStubRepo -Name 'disable-missing'
        Remove-Item -LiteralPath (Join-Path $stub.IconEditorRoot '.github/actions/restore-setup-lv-source/RestoreSetupLVSource.ps1') -Force

        $threw = $false
        $exception = $null
        try {
            & $script:disableScript `
                -RepoRoot $stub.RepoRoot `
                -IconEditorRoot $stub.IconEditorRoot `
                -Versions 2026 `
                -Bitness 64
        } catch {
            $threw = $true
            $exception = $_.Exception
        }
        $threw | Should -BeTrue
        $exception.Message | Should -Match 'Icon editor dev-mode helper'
    }

    It 'throws when reset helper script is missing' {
        $stub = Initialize-DevModeStubRepo -Name 'disable-reset-missing'
        Remove-Item -LiteralPath (Join-Path $stub.RepoRoot 'tools/icon-editor/Reset-IconEditorWorkspace.ps1') -Force

        { & $script:disableScript -RepoRoot $stub.RepoRoot -IconEditorRoot $stub.IconEditorRoot -Versions 2026 -Bitness 64 } | Should -Throw '*Icon editor dev-mode helper*'
    }
}
