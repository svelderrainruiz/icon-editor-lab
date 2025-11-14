#Requires -Version 7.0
Set-StrictMode -Version Latest

function Resolve-LocalCiDevModeAction {
    [CmdletBinding()]
    param(
        [string]$RequestedAction,
        [bool]$DisableAtEnd = $true
    )

    $normalized = if ($RequestedAction) {
        $RequestedAction.Trim().ToLowerInvariant()
    } else {
        'enable'
    }

    if ($normalized -notin @('enable','disable','skip')) {
        throw "Unsupported DevModeAction '$RequestedAction'. Use Enable, Disable, or Skip."
    }

    $override = $null
    if ($DisableAtEnd -and $normalized -eq 'disable') {
        $override = "[25-DevMode] DevModeDisableAtEnd=True; deferring disable to Stage 55 (DevModeCleanup)."
        $normalized = 'enable'
    }

    return [pscustomobject]@{
        Action  = $normalized
        Message = $override
    }
}

function Resolve-DevModeForceClosePreference {
    [CmdletBinding()]
    param(
        [bool]$ConfiguredAllowForceClose = $false
    )

    $preference = [bool]$ConfiguredAllowForceClose
    $envValue = [Environment]::GetEnvironmentVariable('LOCALCI_DEV_MODE_FORCE_CLOSE')
    if ($envValue) {
        $text = $envValue.ToString().Trim().ToLowerInvariant()
        switch ($text) {
            '1' { return $true }
            'true' { return $true }
            'yes' { return $true }
            'on' { return $true }
            '0' { return $false }
            'false' { return $false }
            'no' { return $false }
            'off' { return $false }
        }
    }
    return $preference
}

Export-ModuleMember -Function Resolve-LocalCiDevModeAction, Resolve-DevModeForceClosePreference
