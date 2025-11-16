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
$scriptPath = Join-Path $repoRoot 'src/tools/Check-WorkflowDrift.ps1'

 $workflowNewStub = {
    param([Parameter(Mandatory)][string]$TmpRoot)

    $stubDir = Join-Path $TmpRoot ("wf-stubs-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $stubDir | Out-Null
    $pythonStub = @"
@echo off
setlocal EnableDelayedExpansion
echo %*>>"{0}\python.log"
if "%1"=="-m" (
    exit /b 0
)
set exitcode=%WF_PY_EXIT_CODE%
if "!exitcode!"=="" set exitcode=0
set writeExit=%WF_PY_WRITE_EXIT_CODE%
if "!writeExit!"=="" set writeExit=0
for %%A in (%*) do (
    if "%%~A"=="--write" (
        exit /b !writeExit!
    )
)
exit /b !exitcode!
"@ -f $stubDir
    Set-Content -LiteralPath (Join-Path $stubDir 'python.cmd') -Value $pythonStub -Encoding ascii

    $gitStub = @"
@echo off
setlocal EnableDelayedExpansion
if /I "%1"=="status" (
    if /I "%2"=="--porcelain" (
        if "%WF_GIT_DIRTY%"=="1" (
            echo M %3
        )
        if "%WF_GIT_EXTRA%"=="1" (
            echo M README.md
        )
        exit /b 0
    )
)
if /I "%1"=="add" exit /b 0
if /I "%1"=="commit" (
    if "%WF_GIT_COMMIT_FAIL%"=="1" exit /b 1
    exit /b 0
)
if /I "%1"=="diff" exit /b 0
if /I "%1"=="--no-pager" exit /b 0
echo git stub %*>>"{0}\git.log"
exit /b 0
"@ -f $stubDir
    Set-Content -LiteralPath (Join-Path $stubDir 'git.cmd') -Value $gitStub -Encoding ascii
    return $stubDir
}

$workflowInvokeScript = {
    param(
        [Parameter(Mandatory)][string]$ScriptPath,
        [Parameter(Mandatory)][string]$RepoPath,
        [Parameter(Mandatory)][string]$StubDir,
        [string[]]$Arguments,
        [hashtable]$ExtraEnv
    )

    $pwshPath = (Get-Command pwsh -ErrorAction Stop).Source
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $pwshPath
    $psi.ArgumentList.Add('-NoLogo')
    $psi.ArgumentList.Add('-NoProfile')
    $psi.ArgumentList.Add('-File')
    $psi.ArgumentList.Add($ScriptPath)
    foreach ($arg in $Arguments) { $psi.ArgumentList.Add($arg) }
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.WorkingDirectory = $RepoPath
    $psi.Environment['PATH'] = "$StubDir;$($env:PATH)"
    if ($ExtraEnv) {
        foreach ($entry in $ExtraEnv.GetEnumerator()) {
            $psi.Environment[$entry.Key] = [string]$entry.Value
        }
    }
    $proc = [System.Diagnostics.Process]::Start($psi)
    try {
        $proc.WaitForExit() | Out-Null
        return [pscustomobject]@{
            ExitCode = $proc.ExitCode
            StdOut   = $proc.StandardOutput.ReadToEnd()
            StdErr   = $proc.StandardError.ReadToEnd()
        }
    } finally {
        $proc.Dispose()
    }
}

Describe 'Check-WorkflowDrift.ps1 (script run)' {
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        It 'skips when Check-WorkflowDrift.ps1 is absent' -Skip {
            # Script not present.
        }
        return
    }

    if (-not $IsWindows) {
        It 'skips on non-Windows hosts' -Skip {
            # Stubs rely on .cmd launchers.
        }
        return
    }

    It 'completes staging flow when python succeeds' {
        $stubDir = & $workflowNewStub -TmpRoot $tmp
        $envVars = @{
            'WF_PY_EXIT_CODE' = '0'
            'WF_GIT_DIRTY'    = '0'
        }
        try {
            $result = & $workflowInvokeScript -ScriptPath $scriptPath -RepoPath $repoRoot -StubDir $stubDir -ExtraEnv $envVars -Arguments @('-Stage','-CommitMessage','ci-bot')
            $result.ExitCode | Should -Be 0
            $result.StdOut | Should -Match 'Workflow drift check passed'
        }
        finally {
            Remove-Item -LiteralPath $stubDir -Recurse -Force
        }
    }

    It 'applies auto-fix path when python returns exit code 3' {
        $stubDir = & $workflowNewStub -TmpRoot $tmp
        $envVars = @{
            'WF_PY_EXIT_CODE'       = '3'
            'WF_PY_WRITE_EXIT_CODE' = '0'
            'WF_GIT_DIRTY'          = '1'
        }
        try {
            $args = @('-AutoFix','-Stage','-CommitMessage','auto-fix')
            $result = & $workflowInvokeScript -ScriptPath $scriptPath -RepoPath $repoRoot -StubDir $stubDir -ExtraEnv $envVars -Arguments $args
            $result.ExitCode | Should -Be 0
            ($result.StdOut + $result.StdErr) | Should -Match 'Workflow drift detected'
        }
        finally {
            Remove-Item -LiteralPath $stubDir -Recurse -Force
        }
    }

    It 'propagates failure exit codes from python' {
        $stubDir = & $workflowNewStub -TmpRoot $tmp
        $envVars = @{ 'WF_PY_EXIT_CODE' = '5' }
        try {
            $result = & $workflowInvokeScript -ScriptPath $scriptPath -RepoPath $repoRoot -StubDir $stubDir -ExtraEnv $envVars -Arguments @()
            $result.ExitCode | Should -Be 5
        }
        finally {
            Remove-Item -LiteralPath $stubDir -Recurse -Force
        }
    }
}
