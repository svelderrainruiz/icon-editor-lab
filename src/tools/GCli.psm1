#Requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Providers = @{}

<#
.SYNOPSIS
Register-GCliProvider: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Register-GCliProvider {
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
Get-GCliProviders: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Get-GCliProviders {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param()

    return $script:Providers.GetEnumerator() | ForEach-Object { $_.Value }
}

<#
.SYNOPSIS
Get-GCliProviderByName: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Get-GCliProviderByName {
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
Import-GCliProviderModules: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Import-GCliProviderModules {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

    $providerRoot = Join-Path $PSScriptRoot 'providers'
    if (-not (Test-Path -LiteralPath $providerRoot -PathType Container)) { return }

    $modules = Get-ChildItem -Path $providerRoot -Directory -ErrorAction SilentlyContinue
    foreach ($modDir in $modules) {
        $modulePath = $null
        $manifestPath = Join-Path $modDir.FullName ("{0}.Provider.psd1" -f $modDir.Name)
        if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
            $modulePath = $manifestPath
        } else {
            $fallbackPath = Join-Path $modDir.FullName 'Provider.psm1'
            if (Test-Path -LiteralPath $fallbackPath -PathType Leaf) {
                $modulePath = $fallbackPath
            }
        }
        if (-not $modulePath) { continue }
        try {
            $moduleInfo = Import-Module $modulePath -Force -PassThru
            $command = Get-Command -Name 'New-GCliProvider' -Module $moduleInfo.Name -ErrorAction Stop
            $provider = & $command
            if (-not $provider) { throw 'New-GCliProvider returned null.' }
            Register-GCliProvider -Provider $provider
        } catch {
            Write-Warning ("Failed to import g-cli provider from {0}: {1}" -f $modulePath, $_.Exception.Message)
        }
    }
}

Import-GCliProviderModules

<#
.SYNOPSIS
Get-GCliInvocation: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Get-GCliInvocation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Operation,
        [hashtable]$Params,
        [string]$ProviderName
    )

    $candidates = @()
    if ($ProviderName) {
        $provider = Get-GCliProviderByName -Name $ProviderName
        if (-not $provider) {
            throw "g-cli provider '$ProviderName' is not registered."
        }
        $candidates = @($provider)
    } else {
        $candidates = Get-GCliProviders
    }

    foreach ($provider in $candidates) {
        if (-not $provider.Supports($Operation)) { continue }

        $binary = $provider.ResolveBinaryPath()
        if ([string]::IsNullOrWhiteSpace($binary)) {
            throw ("Provider '{0}' failed to resolve g-cli binary path." -f $provider.Name())
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

    $available = (Get-GCliProviders | ForEach-Object { $_.Name() }) -join ', '
    throw "No g-cli provider registered that supports operation '$Operation'. Registered providers: $available"
}

Export-ModuleMember -Function Get-GCliInvocation, Get-GCliProviders, Get-GCliProviderByName


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
