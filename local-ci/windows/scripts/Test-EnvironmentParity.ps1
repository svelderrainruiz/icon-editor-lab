#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RepoRoot,
    [Parameter(Mandatory)][string]$ProfilesPath,
    [Parameter(Mandatory)][string]$ProfileName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-AbsolutePath {
    param([string]$Path, [string]$BasePath)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    }
    $combined = [System.IO.Path]::Combine($BasePath, $Path)
    return (Resolve-Path -LiteralPath $combined -ErrorAction Stop).Path
}

function Expand-RequirementPath {
    param([string]$Path, [string]$RepoRoot)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $Path }
    $expanded = $Path -replace '\{\{RepoRoot\}\}', $RepoRoot
    return [System.Environment]::ExpandEnvironmentVariables($expanded)
}

$repoResolved = (Resolve-Path -LiteralPath $RepoRoot).Path
$profilesResolved = Resolve-AbsolutePath -Path $ProfilesPath -BasePath $repoResolved
if (-not (Test-Path -LiteralPath $profilesResolved -PathType Leaf)) {
    throw "[Test-EnvironmentParity] Profiles manifest not found at $profilesResolved"
}

$manifest = Import-PowerShellDataFile -LiteralPath $profilesResolved
if (-not $manifest -or -not $manifest.Profiles) {
    throw "[Test-EnvironmentParity] No profiles defined in $profilesResolved"
}

$profile = $manifest.Profiles | Where-Object { $_.Name -eq $ProfileName } | Select-Object -First 1
if (-not $profile) {
    throw "[Test-EnvironmentParity] Profile '$ProfileName' not found in $profilesResolved"
}

$displayName = if ($profile.DisplayName) { $profile.DisplayName } else { $ProfileName }
Write-Host ("[EnvParity] Validating profile '{0}'" -f $displayName) -ForegroundColor Cyan

$requirements = @($profile.Requirements)
if (-not $requirements -or $requirements.Count -eq 0) {
    Write-Warning "[EnvParity] Profile has no requirements defined; nothing to validate."
    return
}

$failures = @()

foreach ($requirement in $requirements) {
    $type = if ($requirement.Type) { $requirement.Type.ToLowerInvariant() } else { 'file' }
    $isOptional = $false
    if ($null -ne $requirement) {
        # Support hashtable and PSCustomObject shapes without StrictMode property errors
        if ($requirement -is [System.Collections.IDictionary]) {
            if ($requirement.ContainsKey('Optional')) { $isOptional = [bool]$requirement['Optional'] }
        } elseif ($requirement.PSObject -and $requirement.PSObject.Properties.Match('Optional').Count -gt 0) {
            $isOptional = [bool]$requirement.Optional
        }
    }
    $description = $requirement.Description
    switch ($type) {
        'file' {
            $path = Expand-RequirementPath -Path $requirement.Path -RepoRoot $repoResolved
            $exists = $path -and (Test-Path -LiteralPath $path -PathType Leaf)
            if (-not $exists) {
                if ($isOptional) {
                    Write-Warning ("[EnvParity] Optional file missing: {0}" -f ($description ? $description : $path))
                } else {
                    $failures += ("Missing file: {0}" -f ($description ? $description : $path))
                }
            } else {
                Write-Host ("[EnvParity] Found file: {0}" -f ($description ? $description : $path)) -ForegroundColor DarkGray
            }
        }
        'directory' {
            $path = Expand-RequirementPath -Path $requirement.Path -RepoRoot $repoResolved
            $exists = $path -and (Test-Path -LiteralPath $path -PathType Container)
            if (-not $exists) {
                if ($isOptional) {
                    Write-Warning ("[EnvParity] Optional directory missing: {0}" -f ($description ? $description : $path))
                } else {
                    $failures += ("Missing directory: {0}" -f ($description ? $description : $path))
                }
            } else {
                Write-Host ("[EnvParity] Found directory: {0}" -f ($description ? $description : $path)) -ForegroundColor DarkGray
            }
        }
        'command' {
            $commandName = $requirement.Command
            if ([string]::IsNullOrWhiteSpace($commandName)) {
                $failures += "Requirement missing 'Command' property."
                continue
            }
            $cmd = Get-Command $commandName -ErrorAction SilentlyContinue
            if (-not $cmd) {
                if ($isOptional) {
                    Write-Warning ("[EnvParity] Optional command not found: {0}" -f $commandName)
                } else {
                    $failures += ("Command not found: {0}" -f $commandName)
                }
            } else {
                Write-Host ("[EnvParity] Found command: {0}" -f $commandName) -ForegroundColor DarkGray
            }
        }
        'envvar' {
            $varName = $requirement.Name
            if ([string]::IsNullOrWhiteSpace($varName)) {
                $failures += "Environment variable requirement missing 'Name'."
                continue
            }
            $value = [System.Environment]::GetEnvironmentVariable($varName)
            if ([string]::IsNullOrWhiteSpace($value)) {
                if ($isOptional) {
                    Write-Warning ("[EnvParity] Optional environment variable unset: {0}" -f $varName)
                } else {
                    $failures += ("Environment variable '{0}' is not set." -f $varName)
                }
            } else {
                Write-Host ("[EnvParity] Env var {0}={1}" -f $varName, $value) -ForegroundColor DarkGray
            }
        }
        default {
            $failures += ("Unknown requirement type '{0}' for entry '{1}'." -f $type, ($description ? $description : $requirement.Path))
        }
    }
}

if ($failures.Count -gt 0) {
    $message = "[EnvParity] Environment parity check failed:`n - " + ($failures -join "`n - ")
    throw $message
}

Write-Host "[EnvParity] Environment parity requirements satisfied." -ForegroundColor Green
