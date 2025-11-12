Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Helper module for g-cli provider integration.
function Invoke-GCliClose {
  param(
    [Parameter(Mandatory)][string]$LabVIEWExePath,
    [Parameter()][string]$Arguments
  )
  $message = "Stub g-cli close invoked with $Arguments"
  Write-Verbose $message
  return [pscustomobject]@{
    LabVIEWExePath = $LabVIEWExePath
    Arguments      = $Arguments
    Message        = $message
  }
}

Export-ModuleMember -Function Invoke-GCliClose
