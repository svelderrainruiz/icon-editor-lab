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
$scriptPath = Join-Path $repoRoot 'local-ci/ubuntu/scripts/detect_vi_changes.py'

if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    Describe 'detect_vi_changes.py' {
        It 'skips when detect_vi_changes.py is absent' -Skip {
            # Script not present.
        }
    }
    return
}

$python = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $python) {
    Describe 'detect_vi_changes.py' {
        It 'skips when python3 is unavailable' -Skip {
            # Python runtime missing.
        }
    }
    return
}

Describe 'detect_vi_changes.py' {
    It 'detects changed VI files between commits' {
        $repo = Join-Path $TestDrive 'vi-repo'
        git init $repo | Out-Null
        git -C $repo config user.email 'test@example.com'
        git -C $repo config user.name 'Test Runner'
        $viPath = Join-Path $repo 'Sample.vi'
        Set-Content -LiteralPath $viPath -Value 'base'
        git -C $repo add Sample.vi | Out-Null
        git -C $repo commit -m 'base' | Out-Null
        $base = (git -C $repo rev-parse HEAD).Trim()
        Set-Content -LiteralPath $viPath -Value 'changed'
        git -C $repo commit -am 'change' | Out-Null
        $head = (git -C $repo rev-parse HEAD).Trim()
        $output = Join-Path $TestDrive 'vi-list.txt'
        $localRoot = $env:WORKSPACE_ROOT
        if (-not $localRoot) { $localRoot = '/mnt/data/repo_local' }
        $repoRootLocal = (Resolve-Path -LiteralPath $localRoot).Path
        $detectScript = Join-Path $repoRootLocal 'local-ci/ubuntu/scripts/detect_vi_changes.py'
        python3 $detectScript --repo $repo --base $base --head $head --output $output
        $results = Get-Content -LiteralPath $output
        $results | Should -Contain 'Sample.vi'
    }

    It 'emits empty list when base is missing' {
        $repo = Join-Path $TestDrive 'vi-repo2'
        git init $repo | Out-Null
        $output = Join-Path $TestDrive 'empty.txt'
        $localRoot = $env:WORKSPACE_ROOT
        if (-not $localRoot) { $localRoot = '/mnt/data/repo_local' }
        $repoRootLocal = (Resolve-Path -LiteralPath $localRoot).Path
        $detectScript = Join-Path $repoRootLocal 'local-ci/ubuntu/scripts/detect_vi_changes.py'
        python3 $detectScript --repo $repo --output $output
        (Get-Content -LiteralPath $output | Measure-Object).Count | Should -Be 0
    }
}


