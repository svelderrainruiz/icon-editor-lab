#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Workflow,

    [string]$RequestPath,

    [string[]]$AdditionalArgs,

    [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-PublishedCliPath {
    $candidates = @(
        $env:XCLI_PUBLISHED_PATH,
        $env:XCLI_BIN,
        $env:XCLI_EXE_PATH
    ) | Where-Object { $_ }

    foreach ($candidate in $candidates) {
        try {
            $resolved = Resolve-Path -LiteralPath $candidate -ErrorAction Stop
            if ($resolved) {
                return $resolved.ProviderPath
            }
        } catch {}
    }

    if ($env:XCLI_USE_PUBLISHED -eq '1') {
        $command = $null
        try { $command = Get-Command 'x-cli' -ErrorAction Stop } catch {}
        if ($command -and $command.CommandType -eq 'Application') {
            return $command.Source
        }
    }

    return $null
}

function Resolve-RepoRoot {
    param([string]$Root)
    if ([string]::IsNullOrWhiteSpace($Root)) {
        $scriptBase = $null
        if ($MyInvocation.MyCommand -and $MyInvocation.MyCommand.PSObject.Properties['Path']) {
            $scriptBase = Split-Path -Parent $MyInvocation.MyCommand.Path
        }
        if (-not $scriptBase -and $PSScriptRoot) {
            $scriptBase = $PSScriptRoot
        }
        if (-not $scriptBase) {
            $scriptBase = (Get-Location).ProviderPath
        }
        $Root = Join-Path $scriptBase '..' '..'
    }
    return (Resolve-Path -LiteralPath $Root -ErrorAction Stop).ProviderPath
}

$repoPath = Resolve-RepoRoot -Root $RepoRoot
$cliProject = Join-Path $repoPath 'tools/x-cli-develop/src/XCli/XCli.csproj'
if (-not (Test-Path -LiteralPath $cliProject -PathType Leaf)) {
    throw "XCli project not found at '$cliProject'."
}

$publishedCli = Resolve-PublishedCliPath
$trimChars = @([char]34, [char]39, [char]92)
$exePath = $null
$argsList = @()
if ($publishedCli) {
    $exePath = $publishedCli
    $workflowArg = $Workflow.Trim().Trim($trimChars)
    $argsList += $workflowArg
} else {
    $exePath = 'dotnet'
    $argsList += @('run', '--project', $cliProject, '--', $Workflow)
}

if ($RequestPath) {
    $resolvedRequest = Resolve-Path -LiteralPath $RequestPath -ErrorAction Stop
    $requestArg = $resolvedRequest.ProviderPath.Trim().Trim($trimChars)
    $argsList += @('--request', $requestArg)
}

if ($AdditionalArgs) {
    $argsList += $AdditionalArgs
}

if (-not $env:XCLI_ALLOW_PROCESS_START) {
    $env:XCLI_ALLOW_PROCESS_START = '1'
}
if (-not $env:XCLI_REPO_ROOT) {
    $env:XCLI_REPO_ROOT = $repoPath
}

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exePath
foreach ($arg in $argsList) {
    [void]$psi.ArgumentList.Add($arg)
}
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError  = $true

$process = [System.Diagnostics.Process]::Start($psi)
$stdOut = $process.StandardOutput.ReadToEnd()
$stdErr = $process.StandardError.ReadToEnd()
$process.WaitForExit()

if ($stdOut) { Write-Host $stdOut.TrimEnd() }
if ($stdErr) {
    $trimmedErr = $stdErr.TrimEnd()
    if ($process.ExitCode -eq 0) {
        Write-Host $trimmedErr
    }
    else {
        Write-Error $trimmedErr
    }
}

if ($process.ExitCode -ne 0) {
    throw "x-cli workflow '$Workflow' failed with exit code $($process.ExitCode)."
}
