$root = $env:WORKSPACE_ROOT
if (-not $root) { $root = '/mnt/data/repo_local' }
if (-not (Test-Path -LiteralPath $root -PathType Container)) {
    $scriptDir = Split-Path -Parent $PSCommandPath
    $probe = $scriptDir
    while ($probe -and (Split-Path -Leaf $probe) -ne 'tests') {
        $next = Split-Path -Parent $probe
        if (-not $next -or $next -eq $probe) { break }
        $probe = $next
    }
    if ($probe -and (Split-Path -Leaf $probe) -eq 'tests') {
        $root = Split-Path -Parent $probe
    }
    else {
        $root = $scriptDir
    }
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


