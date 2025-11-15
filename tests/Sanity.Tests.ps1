$root = $env:WORKSPACE_ROOT
if (-not $root) { $root = '/mnt/data/repo_local' }
if (-not (Test-Path -LiteralPath $root -PathType Container)) {
    $root = (Resolve-Path -LiteralPath '.').Path
}
$repoRoot = (Resolve-Path -LiteralPath $root).Path
$script:root = $root
$script:repoRoot = $repoRoot
$tmp = Join-Path $repoRoot '.tmp-tests'
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

Describe 'Repo Sanity' {
  It 'has a docs folder' {
    (Test-Path ([System.IO.Path]::Combine($script:repoRoot,'docs'))) | Should -BeTrue
  }
}


