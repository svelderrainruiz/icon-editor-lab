param([Parameter(Mandatory=$true)][string]$RunId)
$here = (Get-Location).Path
& "$here\tools\windows\watch.ps1" -RepoRoot $here -PollSec 1  # reuse logic once
