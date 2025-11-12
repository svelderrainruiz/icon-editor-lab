Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-LabVIEWCliPath {
  [CmdletBinding()]
  param(
    [Parameter()][ValidateNotNullOrEmpty()][string[]]$Candidates
  )

  if ($env:LABVIEWCLI_PATH) {
    return $env:LABVIEWCLI_PATH
  }

  $candidates = if ($Candidates -and $Candidates.Count) {
    $Candidates
  }
  else {
    @('labviewcli')
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

  return $candidates[-1]
}

function Invoke-LabVIEWCli {
  [CmdletBinding()]
  param(
    [Parameter()][string]$Command,
    [Parameter()][string[]]$AdditionalArguments,
    [Parameter()][switch]$NoSplash,
    [Parameter()][int]$TimeoutSeconds = 120
  )

  $path = Get-LabVIEWCliPath
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
    }
    catch {
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

function Invoke-LabVIEWCliClose {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$LabVIEWExePath,
    [Parameter()][string]$Arguments
  )
  $message = "labviewcli close stub invoked with $Arguments"
  Write-Verbose $message
  return [pscustomobject]@{
    LabVIEWExePath = $LabVIEWExePath
    Arguments      = $Arguments
    Message        = $message
  }
}

Export-ModuleMember -Function Get-LabVIEWCliPath, Invoke-LabVIEWCli, Invoke-LabVIEWCliClose
