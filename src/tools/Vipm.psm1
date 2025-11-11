#Requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Providers = @{}

<#
.SYNOPSIS
Register-VipmProvider: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Register-VipmProvider {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param([Parameter(Mandatory)][object]$Provider)

    # ShouldProcess guard: honor -WhatIf / -Confirm
    if (-not $PSCmdlet.ShouldProcess($MyInvocation.MyCommand.Name, 'Execute')) { return }

    foreach ($member in @('Name','ResolveBinaryPath','Supports','BuildArgs')) {
        if (-not ($Provider | Get-Member -Name $member -ErrorAction SilentlyContinue)) {
            throw "Provider registration failed: missing required method '$member'."
        }
    }

    $name = $Provider.Name()
    if ([string]::IsNullOrWhiteSpace($name)) {
        throw 'Provider registration failed: Name() returned empty.'
    }

    $script:Providers[$name.ToLowerInvariant()] = $Provider
}

<#
.SYNOPSIS
Get-VipmProviders: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Get-VipmProviders {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param()

    return $script:Providers.GetEnumerator() | ForEach-Object { $_.Value }
}

<#
.SYNOPSIS
Get-VipmProviderByName: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Get-VipmProviderByName {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param([Parameter(Mandatory)][string]$Name)

    $key = $Name.ToLowerInvariant()
    if ($script:Providers.ContainsKey($key)) {
        return $script:Providers[$key]
    }
    return $null
}

<#
.SYNOPSIS
Import-VipmProviderModules: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Import-VipmProviderModules {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

    $rootPath = $PSScriptRoot
    if (-not $rootPath) {
        $maybePath = $null
        if ($PSCommandPath) {
            $maybePath = $PSCommandPath
        } elseif ($MyInvocation -and $MyInvocation.MyCommand -and ($MyInvocation.MyCommand | Get-Member -Name Path -ErrorAction SilentlyContinue)) {
            $maybePath = $MyInvocation.MyCommand.Path
        }
        if ($maybePath) {
            $rootPath = Split-Path -Parent $maybePath
        }
    }
    if (-not $rootPath) { return }
    $providerRoot = Join-Path $rootPath 'providers'
    if (-not (Test-Path -LiteralPath $providerRoot -PathType Container)) { return }

    $providerDirs = Get-ChildItem -Path $providerRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like 'vipm*' }

    foreach ($dir in $providerDirs) {
        $modulePath = $null
        $manifestPath = Join-Path $dir.FullName ("{0}.Provider.psd1" -f $dir.Name)
        if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
            $modulePath = $manifestPath
        } else {
            $fallback = Join-Path $dir.FullName 'Provider.psm1'
            if (Test-Path -LiteralPath $fallback -PathType Leaf) {
                $modulePath = $fallback
            }
        }
        if (-not $modulePath) { continue }

        try {
            $moduleInfo = Import-Module $modulePath -Force -PassThru
            $command = Get-Command -Name 'New-VipmProvider' -Module $moduleInfo.Name -ErrorAction Stop
            $provider = & $command
            if (-not $provider) { throw 'New-VipmProvider returned null.' }
            Register-VipmProvider -Provider $provider
        } catch {
            Write-Warning ("Failed to import VIPM provider from {0}: {1}" -f $modulePath, $_.Exception.Message)
        }
    }
}

Import-VipmProviderModules

<#
.SYNOPSIS
Get-VipmInvocation: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Get-VipmInvocation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Operation,
        [hashtable]$Params,
        [string]$ProviderName
    )

    $candidates = @()
    if ($ProviderName) {
        $provider = Get-VipmProviderByName -Name $ProviderName
        if (-not $provider) {
            throw "VIPM provider '$ProviderName' is not registered."
        }
        $candidates = @($provider)
    } else {
        $candidates = Get-VipmProviders
    }

    foreach ($provider in $candidates) {
        if (-not $provider.Supports($Operation)) { continue }

        try {
            $binary = $provider.ResolveBinaryPath()
        } catch {
            $message = "Provider '{0}' failed to resolve VIPM binary path. Configure VIPM_PATH/VIPM_EXE_PATH or update configs/labview-paths*.json. ({1})" -f $provider.Name(), $_.Exception.Message
            throw $message
        }

        if ([string]::IsNullOrWhiteSpace($binary)) {
            throw ("Provider '{0}' returned an empty VIPM path. Configure VIPM_PATH/VIPM_EXE_PATH or update configs/labview-paths*.json." -f $provider.Name())
        }

        $arguments = $provider.BuildArgs($Operation, $Params)
        if (-not $arguments) {
            $arguments = @()
        }

        return [pscustomobject]@{
            Provider  = $provider.Name()
            Binary    = $binary
            Arguments = @($arguments)
        }
    }

    $available = (Get-VipmProviders | ForEach-Object { $_.Name() }) -join ', '
    throw "No VIPM provider registered that supports operation '$Operation'. Registered providers: $available"
}

Export-ModuleMember -Function Get-VipmInvocation, Get-VipmProviders, Get-VipmProviderByName, Register-VipmProvider

<#
.SYNOPSIS
Test-ValidLabel: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Test-ValidLabel {
  param([Parameter(Mandatory)][string]$Label)
  if ($Label -notmatch '^[A-Za-z0-9._-]{1,64}$') { throw "Invalid label: $Label" }
}

<#
.SYNOPSIS
Invoke-WithTimeout: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
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
