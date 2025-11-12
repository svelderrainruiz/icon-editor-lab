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

function Get-LabVIEWGCliPath {
  [CmdletBinding()]
  param(
    [Parameter()][ValidateNotNullOrEmpty()][string]$Manager = 'labviewcli',
    [Parameter()][string[]]$Candidates
  )
  if ($env:LABVIEWGCLI_PATH) {
    return $env:LABVIEWGCLI_PATH
  }

  $candidates = if ($Candidates -and $Candidates.Count) {
    $Candidates
  } else {
    @($Manager, 'labviewcli', 'g-cli')
  }
  $candidates = $candidates | Where-Object { $_ }
  foreach ($candidate in $candidates) {
    $command = Get-Command $candidate -CommandType Application -ErrorAction SilentlyContinue
    if ($command) {
      return $command.Source
    }

    if (Test-Path -LiteralPath $candidate) {
      return (Resolve-Path -LiteralPath $candidate).Path
    }
  }

  return $Manager
}

function Invoke-LabVIEWGCli {
  [CmdletBinding()]
  param(
    [Parameter()][string]$Manager = 'labviewcli',
    [Parameter()][string]$Command,
    [Parameter()][string[]]$AdditionalArguments,
    [Parameter()][switch]$NoSplash,
    [Parameter()][int]$TimeoutSeconds = 120
  )

  $path = Get-LabVIEWGCliPath -Manager $Manager
  $arguments = @()

  if ($Command) {
    $arguments += $Command
  }

  if ($NoSplash) {
    $arguments += '-NoSplash'
  }

  if ($AdditionalArguments) {
    $arguments += $AdditionalArguments
  }

  $process = Start-Process -FilePath $path -ArgumentList $arguments -NoNewWindow -PassThru

  if ($TimeoutSeconds -gt 0) {
    try {
      Wait-Process -Id $process.Id -TimeoutSeconds $TimeoutSeconds -ErrorAction Stop
    } catch {
      Stop-Process -Id $process.Id -Force
      throw
    }
  }

  return [pscustomobject]@{
    Path      = $path
    Arguments = $arguments
    ProcessId = $process.Id
  }
}

Export-ModuleMember -Function Invoke-GCliClose, Get-LabVIEWGCliPath, Invoke-LabVIEWGCli
