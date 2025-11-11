# Redaction.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'; $PSModuleAutoLoadingPreference='None'

function Write-LogSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [Parameter()][ValidateSet('INFO','WARN','ERROR')][string]$Level = 'INFO'
    )
    # Redact common secret/token patterns (simple heuristic)
    $msg = $Message -replace '([A-Za-z0-9-_]{20,})','****' `
                    -replace '(?i)(secret|token|password)\s*[:=]\s*[^ \t\r\n]+','$1=****'
    $ts = (Get-Date).ToString('s')
    Write-Output "[$ts][$Level] $msg"
}
Export-ModuleMember -Function Write-LogSafe
