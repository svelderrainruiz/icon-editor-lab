#Requires -Version 7.0
[CmdletBinding()]
param(
  [string]$RunRoot
)

$Context = [pscustomobject]@{
  RunRoot = $RunRoot
}

function Set-StageStatus {
  param(
    [psobject]$Context,
    [string]$Status
  )
  if (-not $Context) { return }
  if ($Context.PSObject.Properties['StageStatus']) {
    $Context.StageStatus = $Status
  } else {
    $Context | Add-Member -NotePropertyName StageStatus -NotePropertyValue $Status -Force
  }
}

function Resolve-RepoToolScript {
    param([string[]]$RelativeSegments)
    $contextRepo = (Get-Location).Path
    $candidates = @()
    $candidates += (Join-Path $contextRepo (Join-Path 'src/tools' (Join-Path -Path $RelativeSegments -Resolve:$false )))
}
