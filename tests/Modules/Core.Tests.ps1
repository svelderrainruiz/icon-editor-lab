$root = $env:WORKSPACE_ROOT
if (-not $root) { $root = '/mnt/data/repo_local' }
if (-not (Test-Path -LiteralPath $root -PathType Container)) {
    $root = (Resolve-Path -LiteralPath '.').Path
}
$repoRoot = (Resolve-Path -LiteralPath $root).Path
$tmp = Join-Path $repoRoot '.tmp-tests'
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$coreModule = Join-Path $repoRoot 'src/Core.psm1'

if (-not (Test-Path -LiteralPath $coreModule -PathType Leaf)) {
    Describe 'src/Core.psm1' {
        It 'skips when Core.psm1 is absent' -Skip {
            # File not present in this repo snapshot.
        }
    }
    return
}


