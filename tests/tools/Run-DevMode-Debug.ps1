#Requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateSet('Enable','Disable','Debug')]
    [string]$Action = 'Debug',
    [ValidateSet('Real','Simulation','XCliSim')]
    [string]$Provider = 'Real'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-WorkspaceRoot {
    $candidates = New-Object System.Collections.Generic.List[string]

    try {
        $gitRoot = git -C $PSScriptRoot rev-parse --show-toplevel 2>$null
        if ($gitRoot) {
            $resolvedGitRoot = (Resolve-Path -LiteralPath $gitRoot.Trim()).ProviderPath
            $candidates.Add($resolvedGitRoot) | Out-Null
        }
    } catch {}

    if ($env:WORKSPACE_ROOT) {
        $candidates.Add($env:WORKSPACE_ROOT) | Out-Null
    }

    try {
        $repoGuess = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..' '..') -ErrorAction Stop).ProviderPath
        $candidates.Add($repoGuess) | Out-Null
    } catch {}

    $candidates.Add('/mnt/data/repo_local') | Out-Null

    foreach ($candidate in $candidates) {
        if (-not $candidate) { continue }
        try {
            $resolvedCandidate = (Resolve-Path -LiteralPath $candidate -ErrorAction Stop).ProviderPath
        } catch {
            continue
        }
        if (-not (Test-Path -LiteralPath (Join-Path $resolvedCandidate '.git') -PathType Container)) {
            continue
        }
        return $resolvedCandidate
    }

    return $null
}

function New-LvAddonSimulationScript {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )

    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }
    Set-Content -LiteralPath $Path -Value $Content -Encoding utf8
}

function Initialize-DevModeSimulation {
    param(
        [Parameter(Mandatory)][string]$WorkspaceRoot
    )

    $basePath = Join-Path (Join-Path $WorkspaceRoot '.tmp-tests') 'simulation-provider'
    if (Test-Path -LiteralPath $basePath) {
        Remove-Item -LiteralPath $basePath -Recurse -Force
    }
    $lvAddonRoot = Join-Path $basePath 'vendor/labview-icon-editor'
    New-Item -ItemType Directory -Force -Path $lvAddonRoot | Out-Null

    $logPath = Join-Path $basePath 'simulation-log.txt'
    New-Item -ItemType File -Path $logPath -Force | Out-Null

    '<Project Name="LvAddonSimulation"></Project>' | Set-Content -LiteralPath (Join-Path $lvAddonRoot 'lv_icon_editor.lvproj') -Encoding utf8

    $addTokenBody = @'
[CmdletBinding()]
param(
  [string]$MinimumSupportedLVVersion,
  [string]$SupportedBitness,
  [string]$IconEditorRoot,
  [string]$RelativePath,
  [Parameter(ValueFromRemainingArguments=$true)][string[]]$Extra
)
$target = if ($IconEditorRoot) { $IconEditorRoot } elseif ($RelativePath) { $RelativePath } else { $null }
if ($target) {
  "simulation:on-$SupportedBitness" | Set-Content -LiteralPath (Join-Path $target 'dev-mode.txt') -Encoding utf8
}
if ($env:ICONEDITORLAB_SIMULATION_LOG) {
  $line = "[simulation:add-token] version=$MinimumSupportedLVVersion bitness=$SupportedBitness target=$target extra=$($Extra -join ' ')"
  Add-Content -LiteralPath $env:ICONEDITORLAB_SIMULATION_LOG -Value $line -Encoding utf8
}
'@

    $prepareBody = @'
[CmdletBinding()]
param(
  [string]$MinimumSupportedLVVersion,
  [string]$SupportedBitness,
  [string]$IconEditorRoot,
  [string]$RelativePath,
  [Parameter(ValueFromRemainingArguments=$true)][string[]]$Extra
)
$target = if ($IconEditorRoot) { $IconEditorRoot } elseif ($RelativePath) { $RelativePath } else { $null }
if ($env:ICONEDITORLAB_SIMULATION_LOG) {
  $line = "[simulation:prepare] version=$MinimumSupportedLVVersion bitness=$SupportedBitness target=$target extra=$($Extra -join ' ')"
  Add-Content -LiteralPath $env:ICONEDITORLAB_SIMULATION_LOG -Value $line -Encoding utf8
}
'@

    $restoreBody = @'
[CmdletBinding()]
param(
  [string]$MinimumSupportedLVVersion,
  [string]$SupportedBitness,
  [string]$IconEditorRoot,
  [string]$RelativePath,
  [Parameter(ValueFromRemainingArguments=$true)][string[]]$Extra
)
$target = if ($IconEditorRoot) { $IconEditorRoot } elseif ($RelativePath) { $RelativePath } else { $null }
if ($target) {
  "simulation:off-$SupportedBitness" | Set-Content -LiteralPath (Join-Path $target 'dev-mode.txt') -Encoding utf8
}
if ($env:ICONEDITORLAB_SIMULATION_LOG) {
  $line = "[simulation:restore] version=$MinimumSupportedLVVersion bitness=$SupportedBitness target=$target extra=$($Extra -join ' ')"
  Add-Content -LiteralPath $env:ICONEDITORLAB_SIMULATION_LOG -Value $line -Encoding utf8
}
'@

    $closeBody = @'
[CmdletBinding()]
param(
  [string]$MinimumSupportedLVVersion,
  [string]$SupportedBitness,
  [Parameter(ValueFromRemainingArguments=$true)][string[]]$Extra
)
if ($env:ICONEDITORLAB_SIMULATION_LOG) {
  $line = "[simulation:close] version=$MinimumSupportedLVVersion bitness=$SupportedBitness extra=$($Extra -join ' ')"
  Add-Content -LiteralPath $env:ICONEDITORLAB_SIMULATION_LOG -Value $line -Encoding utf8
}
'@

    New-LvAddonSimulationScript -Path (Join-Path $lvAddonRoot '.github/actions/add-token-to-labview/AddTokenToLabVIEW.ps1') -Content $addTokenBody
    New-LvAddonSimulationScript -Path (Join-Path $lvAddonRoot '.github/actions/prepare-labview-source/Prepare_LabVIEW_source.ps1') -Content $prepareBody
    New-LvAddonSimulationScript -Path (Join-Path $lvAddonRoot '.github/actions/restore-setup-lv-source/RestoreSetupLVSource.ps1') -Content $restoreBody
    New-LvAddonSimulationScript -Path (Join-Path $lvAddonRoot '.github/actions/close-labview/Close_LabVIEW.ps1') -Content $closeBody

    return [pscustomobject]@{
        IconEditorRoot = $lvAddonRoot
        LogPath        = $logPath
    }
}

$root = Resolve-WorkspaceRoot
if (-not $root) {
    throw "Unable to resolve workspace root. Set WORKSPACE_ROOT to the cloned repository path."
}

$tmp = Join-Path $root '.tmp-tests'
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

$runnerProfileModule = Join-Path $root 'src/tools/RunnerProfile.psm1'
if (Test-Path -LiteralPath $runnerProfileModule -PathType Leaf) {
    Import-Module -Name $runnerProfileModule -Force -ErrorAction Stop
}

$envInfo = $null
try {
    if (Get-Command -Name Get-RunnerHostEnvironment -ErrorAction SilentlyContinue) {
        $envInfo = Get-RunnerHostEnvironment -LibraryPaths @()
    }
} catch {
    $envInfo = $null
}

if ($envInfo) {
    $owner = if ($envInfo.repoOwner) { $envInfo.repoOwner } else { '<unknown-owner>' }
    $name  = if ($envInfo.repoName)  { $envInfo.repoName  } else { '<unknown-repo>' }
    $summary = "Repo={0}/{1}; HostKind={2}; IsCI={3}; OS={4}; PSEdition={5}; PSVersion={6}; DevModeSupported={7}" -f `
        $owner,
        $name,
        $envInfo.hostKind,
        $envInfo.isCI,
        $envInfo.osFamily,
        $envInfo.psEdition,
        $envInfo.psVersion,
        $envInfo.devModeSupported
    Write-Host "[devmode] $summary"

    if (-not $envInfo.devModeSupported) {
        Write-Warning "[devmode] Dev mode requires Windows + PowerShell 7 (pwsh) on a non-CI host."
        exit 1
    }
} else {
    Write-Host "[devmode] RunnerProfile host environment helpers not available; continuing without heuristics."
}

$enableScript  = Join-Path $root 'src/tools/icon-editor/Enable-DevMode.ps1'
$disableScript = Join-Path $root 'src/tools/icon-editor/Disable-DevMode.ps1'

function Get-VendorToolsModulePath {
    param(
        [Parameter(Mandatory)][string]$RepoRoot
    )

    $candidates = @(
        (Join-Path $RepoRoot 'src/tools/VendorTools.psm1'),
        (Join-Path $RepoRoot 'tools/VendorTools.psm1')
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate -ErrorAction Stop).ProviderPath
        }
    }

    throw "VendorTools module not found under 'src/tools' or 'tools'. Looked in: $($candidates -join ', ')"
}

function Get-LvAddonAllowedHosts {
    $hosts = @('github.com')
    if ($env:ICONEDITORLAB_GITHUB_HOSTS) {
        $extra = $env:ICONEDITORLAB_GITHUB_HOSTS -split '[,; ]+' | Where-Object { $_ }
        if ($extra) {
            $hosts += $extra
        }
    }
    return $hosts | Where-Object { $_ } | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ } | Select-Object -Unique
}

$vendorToolsModule = Get-VendorToolsModulePath -RepoRoot $root
Import-Module -Name $vendorToolsModule -Force -ErrorAction Stop
$allowedHosts = Get-LvAddonAllowedHosts
$strictPathCheck = ($env:ICONEDITORLAB_ENFORCE_GITHUB_PATH -eq '1')

function Write-DevModeFailureSummary {
    param(
        [Parameter(Mandatory)][System.Management.Automation.ErrorRecord]$ErrorRecord,
        [string]$RepoRoot
    )

    $message = $ErrorRecord.Exception.Message
    $lines = $message -split "(`r`n|`n)"
    $primary = $lines | Where-Object {
        $_ -and (
            $_ -match 'Error:' -or
            $_ -match 'Rogue LabVIEW' -or
            $_ -match 'Timed out waiting for app to connect to g-cli'
        )
    } | Select-Object -First 1
    if (-not $primary) {
        $primary = $lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1
    }

    if ($primary) {
        Write-Host ("[devmode] Failure summary: {0}" -f $primary.Trim()) -ForegroundColor Red
    }

    if ($RepoRoot) {
        $latest = Join-Path $RepoRoot 'tests/results/_agent/icon-editor/dev-mode-run/latest-run.json'
        Write-Host ("[devmode] Telemetry: {0}" -f $latest) -ForegroundColor DarkGray
        Write-Host "[devmode] Tip: run tests/tools/Show-LastDevModeRun.ps1 or VS Code task 'Local CI: Show last DevMode run' to inspect the latest dev-mode run." -ForegroundColor DarkGray
    }
}

function Get-IconEditorRoot {
    param(
        [pscustomobject]$EnvInfo
    )

    if ($env:ICONEDITOR_ROOT) {
        return $env:ICONEDITOR_ROOT
    }

    $candidate = Join-Path $root 'vendor/icon-editor'
    if (Test-Path -LiteralPath $candidate -PathType Container) {
        return (Resolve-Path -LiteralPath $candidate -ErrorAction Stop).ProviderPath
    }

    $candidate = Join-Path $root 'vendor/labview-icon-editor'
    if (Test-Path -LiteralPath $candidate -PathType Container) {
        return (Resolve-Path -LiteralPath $candidate -ErrorAction Stop).ProviderPath
    }

    $syncScript = Join-Path $root 'local-ci/windows/scripts/Sync-IconEditorVendor.ps1'
    if (-not (Test-Path -LiteralPath $syncScript -PathType Leaf)) {
        Write-Warning "[devmode] Sync-IconEditorVendor.ps1 not found at $syncScript; cannot auto-vendor labview-icon-editor."
        return $null
    }

    $vendorTarget = Join-Path $root 'vendor/labview-icon-editor'
    $remoteUrls = New-Object System.Collections.Generic.List[string]
    if ($EnvInfo -and $EnvInfo.repoOwner) {
        $remoteUrls.Add(("https://github.com/{0}/labview-icon-editor.git" -f $EnvInfo.repoOwner))
    }
    $remoteUrls.Add('https://github.com/LabVIEW-Community-CI-CD/labview-icon-editor.git')

    foreach ($url in $remoteUrls | Select-Object -Unique) {
        try {
            Write-Host ("[devmode] Auto-vendoring labview-icon-editor from {0} -> {1}" -f $url, $vendorTarget) -ForegroundColor Cyan
            & $syncScript -RepoRoot $root -RemoteUrl $url
            if (Test-Path -LiteralPath $vendorTarget -PathType Container) {
                return (Resolve-Path -LiteralPath $vendorTarget -ErrorAction Stop).ProviderPath
            }
        } catch {
            Write-Warning ("[devmode] Auto-vendor attempt from {0} failed: {1}" -f $url, $_.Exception.Message)
        }
    }

    return $null
}

function Ensure-IconEditorDevModeHelpers {
    param(
        [Parameter(Mandatory)][string]$IconEditorRoot
    )

    $actionsRoot = Join-Path $IconEditorRoot '.github/actions'
    $pipelineRoot = Join-Path $IconEditorRoot 'pipeline/scripts'

    $mappings = @(
        @{
            Source = Join-Path $pipelineRoot 'AddTokenToLabVIEW.ps1'
            Target = Join-Path $actionsRoot 'add-token-to-labview/AddTokenToLabVIEW.ps1'
        },
        @{
            Source = Join-Path $pipelineRoot 'Prepare_LabVIEW_source.ps1'
            Target = Join-Path $actionsRoot 'prepare-labview-source/Prepare_LabVIEW_source.ps1'
        }
    )

    foreach ($entry in $mappings) {
        $src = $entry.Source
        $dst = $entry.Target
        if (Test-Path -LiteralPath $dst -PathType Leaf) {
            continue
        }
        if (-not (Test-Path -LiteralPath $src -PathType Leaf)) {
            Write-Warning ("[devmode] Expected dev-mode helper source '{0}' not found; dev-mode may fail." -f $src)
            continue
        }
        $dstDir = Split-Path -Parent $dst
        if (-not (Test-Path -LiteralPath $dstDir -PathType Container)) {
            New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
        }
        Copy-Item -LiteralPath $src -Destination $dst -Force
        Write-Host ("[devmode] Mirrored dev-mode helper {0} -> {1}" -f $src, $dst) -ForegroundColor DarkGray
    }
}

$simulationContext = $null
if ($Provider -eq 'Simulation') {
    $simulationContext = Initialize-DevModeSimulation -WorkspaceRoot $root
    $env:ICONEDITORLAB_SIMULATION_LOG = $simulationContext.LogPath
    $env:ICONEDITOR_ROOT = $simulationContext.IconEditorRoot
    $strictPathCheck = $false
} elseif ($Provider -eq 'XCliSim') {
    $env:ICONEDITORLAB_PROVIDER = 'XCliSim'
}

Push-Location $root
try {
    switch ($Action) {
        'Enable' {
            if (-not (Test-Path -LiteralPath $enableScript -PathType Leaf)) {
                throw "Enable-DevMode script not found at $enableScript"
            }
            $iconRoot = if ($Provider -eq 'Simulation') { $simulationContext.IconEditorRoot } else { Get-IconEditorRoot -EnvInfo $envInfo }
            if (-not $iconRoot) {
                throw "Icon editor root could not be resolved or auto-vendored. Ensure labview-icon-editor is available under vendor/ or set ICONEDITOR_ROOT."
            }
            if ($Provider -ne 'Simulation') {
                Assert-LVAddonLabPath -Path $iconRoot -Strict:$strictPathCheck -AllowedHosts $allowedHosts | Out-Null
                Ensure-IconEditorDevModeHelpers -IconEditorRoot $iconRoot
            }
            try {
                & $enableScript -RepoRoot $root -IconEditorRoot $iconRoot
            } catch {
                Write-DevModeFailureSummary -ErrorRecord $_ -RepoRoot $root
                throw
            }
        }
        'Disable' {
            if (-not (Test-Path -LiteralPath $disableScript -PathType Leaf)) {
                throw "Disable-DevMode script not found at $disableScript"
            }
            $iconRoot = if ($Provider -eq 'Simulation') { $simulationContext.IconEditorRoot } else { Get-IconEditorRoot -EnvInfo $envInfo }
            if (-not $iconRoot) {
                throw "Icon editor root could not be resolved. Ensure labview-icon-editor is available under vendor/ or set ICONEDITOR_ROOT."
            }
            if ($Provider -ne 'Simulation') {
                Assert-LVAddonLabPath -Path $iconRoot -Strict:$strictPathCheck -AllowedHosts $allowedHosts | Out-Null
                Ensure-IconEditorDevModeHelpers -IconEditorRoot $iconRoot
            }
            try {
                & $disableScript -RepoRoot $root -IconEditorRoot $iconRoot
            } catch {
                Write-DevModeFailureSummary -ErrorRecord $_ -RepoRoot $root
                throw
            }
        }
        default {
            Write-Host "[devmode] Debug action selected; no dev-mode changes invoked."
        }
    }
}
finally {
    Pop-Location
    if ($Provider -eq 'Simulation') {
        Remove-Item Env:ICONEDITOR_ROOT -ErrorAction SilentlyContinue
        Remove-Item Env:ICONEDITORLAB_SIMULATION_LOG -ErrorAction SilentlyContinue
    } elseif ($Provider -eq 'XCliSim') {
        Remove-Item Env:ICONEDITORLAB_PROVIDER -ErrorAction SilentlyContinue
    }
}
