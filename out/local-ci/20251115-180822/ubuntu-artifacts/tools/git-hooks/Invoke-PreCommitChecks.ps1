#Requires -Version 7.0
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:ICONEDITORLAB_SKIP_PRECOMMIT -eq '1') {
    Write-Host 'Icon Editor Lab pre-commit checks skipped (ICONEDITORLAB_SKIP_PRECOMMIT=1).'
    exit 0
}

function Get-WorkspaceRoot {
    $root = $env:WORKSPACE_ROOT
    if (-not $root) { $root = '/mnt/data/repo_local' }
    if (-not (Test-Path -LiteralPath $root)) {
        $fallback = Join-Path $PSScriptRoot '..' '..'
        $root = (Resolve-Path -LiteralPath $fallback -ErrorAction Stop).ProviderPath
    } else {
        $root = (Resolve-Path -LiteralPath $root -ErrorAction Stop).ProviderPath
    }
    return $root
}

$repoRoot = Get-WorkspaceRoot
Push-Location $repoRoot
try {
    $changed = git diff --cached --name-only
    if ($LASTEXITCODE -ne 0) {
        Write-Error 'Pre-commit: git diff --cached failed.'
        exit 1
    }

    if (-not $changed) {
        return
    }

    $scriptFiles = $changed | Where-Object {
        $_.EndsWith('.ps1',   'OrdinalIgnoreCase') -or
        $_.EndsWith('.psm1',  'OrdinalIgnoreCase') -or
        $_.EndsWith('.psd1',  'OrdinalIgnoreCase')
    }

    if (-not $scriptFiles) {
        return
    }

    $violations = @()
    foreach ($relativePath in $scriptFiles) {
        $fullPath = Join-Path $repoRoot $relativePath
        if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
            continue
        }

        $matches = Select-String -LiteralPath $fullPath -Pattern '\b[A-Za-z]:\\' -ErrorAction SilentlyContinue
        if ($matches) {
            $violations += [pscustomobject]@{
                File    = $relativePath
                Matches = $matches
            }
        }
    }

    if ($violations.Count -gt 0) {
        Write-Error "Pre-commit: hard-coded drive-letter paths detected (violates workspace path policy)."
        foreach ($v in $violations) {
            foreach ($m in $v.Matches) {
                Write-Host ("  {0}:{1}: {2}" -f $v.File, $m.LineNumber, $m.Line.Trim())
            }
        }
        Write-Host "Hint: use `$env:WORKSPACE_ROOT`, `Join-Path`, `Resolve-Path`, or `$TestDrive` instead of absolute drive letters."
        exit 1
    }
}
finally {
    Pop-Location
}
*** Add File: tools/git-hooks/Invoke-PrePushChecks.ps1
#Requires -Version 7.0
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:ICONEDITORLAB_SKIP_PREPUSH -eq '1') {
    Write-Host 'Icon Editor Lab pre-push checks skipped (ICONEDITORLAB_SKIP_PREPUSH=1).'
    exit 0
}

function Get-WorkspaceRoot {
    $root = $env:WORKSPACE_ROOT
    if (-not $root) { $root = '/mnt/data/repo_local' }
    if (-not (Test-Path -LiteralPath $root)) {
        $fallback = Join-Path $PSScriptRoot '..' '..'
        $root = (Resolve-Path -LiteralPath $fallback -ErrorAction Stop).ProviderPath
    } else {
        $root = (Resolve-Path -LiteralPath $root -ErrorAction Stop).ProviderPath
    }
    return $root
}

$repoRoot = Get-WorkspaceRoot
Push-Location $repoRoot
try {
    $testsRoot = Join-Path $repoRoot 'tests'
    if (-not (Test-Path -LiteralPath $testsRoot -PathType Container)) {
        Write-Host 'Pre-push: tests folder not found; skipping Pester checks.'
        exit 0
    }

    Write-Host 'Pre-push: running Invoke-Pester -Path tests -CI ...'

    $artifactsRoot = Join-Path $repoRoot 'artifacts'
    if (-not (Test-Path -LiteralPath $artifactsRoot)) {
        New-Item -ItemType Directory -Force -Path $artifactsRoot | Out-Null
    }
    $resultsDir = Join-Path $artifactsRoot 'test-results'
    if (-not (Test-Path -LiteralPath $resultsDir)) {
        New-Item -ItemType Directory -Force -Path $resultsDir | Out-Null
    }
    $resultsXml = Join-Path $resultsDir 'prepush-results.xml'

    try {
        $pesterResult = Invoke-Pester -Path $testsRoot -CI -OutputFormat NUnitXml -OutputFile $resultsXml -PassThru
    } catch {
        Write-Error ("Pre-push: Invoke-Pester failed: {0}" -f $_.Exception.Message)
        exit 1
    }

    $failed = $pesterResult.FailedCount
    if ($failed -gt 0) {
        Write-Error ("Pre-push: {0} test(s) failed; see {1}" -f $failed, $resultsXml)
        exit 1
    }

    Write-Host ("Pre-push: all tests passed; results at {0}" -f $resultsXml)
}
finally {
    Pop-Location
}
*** Update File: README.md
@@
 2. Tag the commit with the next semantic version (e.g., `git tag v0.2.0 && git push origin v0.2.0`).
 3. The `release.yml` workflow runs automatically for `v*` tags or via `workflow_dispatch`, executes the Pester suite, enforces the coverage floors, uploads test/coverage artifacts, and creates the GitHub Release with those artifacts attached.

## Local Git hooks (optional)

- Pre-commit path policy guard: `tools/git-hooks/Invoke-PreCommitChecks.ps1` scans staged PowerShell files for hard-coded drive-letter paths and fails the commit if found.
- Pre-push test gate: `tools/git-hooks/Invoke-PrePushChecks.ps1` runs `Invoke-Pester -Path tests -CI` and writes NUnit XML under `artifacts/test-results`.
- To enable, create `.git/hooks/pre-commit` and `.git/hooks/pre-push` that call these scripts with PowerShell; set `ICONEDITORLAB_SKIP_PRECOMMIT=1` or `ICONEDITORLAB_SKIP_PREPUSH=1` to bypass locally when needed.
