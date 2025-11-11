
$ctx = . "$PSScriptRoot/Tools.Loader.ps1"

Describe "tools/ help synopsis coverage" -Tag 'tools','help' {
  It "Each tool script has a non-empty .SYNOPSIS" -ForEach $ctx.All {
    param($relPath)
    $path = Join-Path $ctx.RepoRoot $relPath
    $help = Get-Help -Full -ErrorAction SilentlyContinue -Name $path
    $help | Should -Not -BeNullOrEmpty
    $help.Synopsis | Should -Not -BeNullOrEmpty
  }
}
