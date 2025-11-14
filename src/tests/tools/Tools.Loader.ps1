
Param()
$ErrorActionPreference = 'Stop'
$here = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$repoRoot = Resolve-Path (Join-Path $here '..' '..')
$toolsRoot = Join-Path $repoRoot 'tools'
$manifestPath = Join-Path $here 'tools-manifest.json'
$Manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
return @{
  RepoRoot   = $repoRoot
  ToolsRoot  = $toolsRoot
  Mutating   = $Manifest.mutating
  NonMutating= $Manifest.non_mutating
  All        = $Manifest.all
}
