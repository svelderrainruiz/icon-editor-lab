# EnvGuard.psm1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'; $PSModuleAutoLoadingPreference='None'

function Get-EnvSnapshot {
    [CmdletBinding()]
    param([string[]]$AllowList = @('PATH','TEMP','TMP','HOME','USERPROFILE'))
    $snap = @{}
    foreach ($name in [Environment]::GetEnvironmentVariables().Keys) {
        if ($AllowList -contains $name) { $snap[$name] = [Environment]::GetEnvironmentVariable($name,'Process') }
    }
    return $snap
}

function Set-EnvFromSnapshot {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Snapshot)
    foreach ($k in $Snapshot.Keys) {
        [Environment]::SetEnvironmentVariable($k, [string]$Snapshot[$k], 'Process')
    }
}

Export-ModuleMember -Function Get-EnvSnapshot, Set-EnvFromSnapshot
