$root = $env:WORKSPACE_ROOT
if (-not $root) { $root = '/mnt/data/repo_local' }
$repoRoot = (Resolve-Path -LiteralPath $root).Path
$tmp = Join-Path $repoRoot '.tmp-tests'
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

Describe "Smoke" {
  It "true is true" {
    $true | Should -BeTrue
  }
}
