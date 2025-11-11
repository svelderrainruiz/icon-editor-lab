# Secure-Process.psm1
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'Validate-Paths.ps1')
$ErrorActionPreference='Stop'; $PSModuleAutoLoadingPreference='None'

function Invoke-ProcessSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter()][string[]]$ArgumentList = @(),
        [Parameter()][int]$TimeoutSec = 600,
        [Parameter()][string]$WorkingDirectory = (Get-Location).Path
    )
    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) { throw "FilePath not found: $FilePath" }
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $FilePath
    $psi.WorkingDirectory = (Validate-PathSafe -Path $WorkingDirectory)
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    foreach ($a in $ArgumentList) { $null = $psi.ArgumentList.Add($a) }

    $p = [System.Diagnostics.Process]::new()
    $p.StartInfo = $psi
    if (-not $p.Start()) { throw "Failed to start process: $FilePath" }
    try {
        if (-not $p.WaitForExit($TimeoutSec * 1000)) {
            try { $p.Kill($true) } catch {}
            throw "Process timed out after $TimeoutSec s: $FilePath"
        }
        $stdout = $p.StandardOutput.ReadToEnd()
        $stderr = $p.StandardError.ReadToEnd()
        return [pscustomobject]@{
            ExitCode = $p.ExitCode
            StdOut = $stdout
            StdErr = $stderr
        }
    } finally {
        if (-not $p.HasExited) { try { $p.Kill($true) } catch {} }
        $p.Dispose()
    }
}
Export-ModuleMember -Function Invoke-ProcessSafe
