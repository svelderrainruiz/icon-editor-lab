Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# <summary>Helper module for g-cli provider integration.</summary>
function Invoke-GCliClose {
  param(
    [Parameter(Mandatory)][string]$LabVIEWExePath,
    [Parameter()][string]$Arguments
  )
  Write-Verbose "Stub g-cli close invoked with $Arguments"
}

Export-ModuleMember -Function Invoke-GCliClose
