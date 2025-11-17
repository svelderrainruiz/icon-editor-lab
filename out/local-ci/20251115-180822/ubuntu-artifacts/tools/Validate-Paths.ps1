# Validate-Paths.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'; $PSModuleAutoLoadingPreference='None'

function Test-PathSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter()][switch]$RequireAbsolute
    )
    if ($Path -match '[;&|`]' -or $Path -match '\.\.') { return $false }
    try {
        $rp = Resolve-Path -LiteralPath $Path -ErrorAction Stop
        if ($RequireAbsolute -and -not ($rp.Path -match '^(?:[A-Za-z]:[\\/]|/)')) { return $false }
        return $true
    } catch { return $false }
}

function Validate-PathSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter()][switch]$RequireAbsolute
    )
    if (-not (Test-PathSafe -Path $Path -RequireAbsolute:$RequireAbsolute)) {
        throw "Unsafe or invalid path: $Path"
    }
    return (Resolve-Path -LiteralPath $Path).Path
}

Export-ModuleMember -Function Test-PathSafe, Validate-PathSafe
