
$ctx = . "$PSScriptRoot/Tools.Loader.ps1"

Describe "tools/ mutating scripts expose -WhatIf via CmdletBinding" -Tag 'tools','whatif' {
  It "Mutating script exposes -WhatIf parameter" -ForEach $ctx.Mutating {
    param($relPath)
    $path = Join-Path $ctx.RepoRoot $relPath
    $cmd = Get-Command -Name $path -ErrorAction Stop
    $cmd.Parameters.ContainsKey('WhatIf') | Should -BeTrue
  }
}
