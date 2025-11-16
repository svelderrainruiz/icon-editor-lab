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
$tmp = Join-Path $repoRoot '.tmp-tests'
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
. (Join-Path $root 'tests/_helpers/Import-ScriptFunctions.ps1')
$scriptPath = Join-Path $repoRoot 'src/tools/Check-DocsLinks.ps1'
$scriptExists = Test-Path -LiteralPath $scriptPath -PathType Leaf
if (-not $scriptExists) {
    Describe 'Check-DocsLinks coverage' {
        It 'skips when Check-DocsLinks.ps1 is absent' -Skip {
            # Script not present in this repo snapshot.
        }
    }
    return
}

Import-ScriptFunctions -Path $scriptPath -FunctionNames @('Match-Any','Test-ValidLabel','Invoke-WithTimeout') | Out-Null

Describe 'Check-DocsLinks coverage' {
    BeforeEach {
        $script:existingJobs = @(Get-Job -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
    }

    AfterEach {
        $currentJobs = @(Get-Job -ErrorAction SilentlyContinue)
        foreach ($job in $currentJobs) {
            if ($script:existingJobs -notcontains $job.Id) {
                Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'Match-Any returns false when the pattern list is empty' {
        Match-Any -value 'docs/index.md' -patterns @() | Should -BeFalse
    }

    It 'Test-ValidLabel rejects invalid characters' {
        try {
            Test-ValidLabel -Label 'bad label!'
            throw 'Expected invalid label rejection.'
        } catch {
            $_.Exception.Message | Should -Match 'Invalid label'
        }
    }

    It 'Invoke-WithTimeout returns job output when the work completes before the timeout' {
        Invoke-WithTimeout -ScriptBlock { 'docs-coverage' } -TimeoutSec 5 | Should -Be 'docs-coverage'
    }

    It 'Invoke-WithTimeout throws when the job exceeds the timeout window' {
        { Invoke-WithTimeout -ScriptBlock { Start-Sleep -Seconds 3 } -TimeoutSec 1 } | Should -Throw '*timed out*'
    }
}
