$root = $env:WORKSPACE_ROOT
if (-not $root) { $root = '/mnt/data/repo_local' }
if (-not (Test-Path -LiteralPath $root -PathType Container)) {
    $root = (Resolve-Path -LiteralPath '.').Path
}
$repoRoot = (Resolve-Path -LiteralPath $root).Path
$tmp = Join-Path $repoRoot '.tmp-tests'
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$buildScript = Join-Path $repoRoot 'tools/Build.ps1'

if (-not (Test-Path -LiteralPath $buildScript -PathType Leaf)) {
    Describe 'tools/Build.ps1' {
        It 'skips when Build.ps1 is absent' -Skip {
            # File not present in this repo snapshot.
        }
    }
    return
}


