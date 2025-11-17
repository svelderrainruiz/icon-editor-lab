#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('vi-compare','vi-analyzer','vipm-apply','vipm-build','vipmcli-build','ppl-build')]
    [string]$Operation,

    [string]$RequestPath,

    [string[]]$Arguments,

    [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$helperPath = Join-Path $PSScriptRoot 'Invoke-XCliWorkflow.ps1'
if (-not (Test-Path -LiteralPath $helperPath -PathType Leaf)) {
    throw "Invoke-XCliWorkflow.ps1 not found at '$helperPath'."
}

$operationMap = @{
    'vi-compare'   = @{ Workflow = 'vi-compare-run'; RequiresRequest = $true }
    'vi-analyzer'  = @{ Workflow = 'vi-analyzer-run'; RequiresRequest = $true }
    'vipm-apply'   = @{ Workflow = 'vipm-apply-vipc'; RequiresRequest = $true }
    'vipm-build'   = @{ Workflow = 'vipm-build-vip'; RequiresRequest = $true }
    'vipmcli-build'= @{ Workflow = 'vipmcli-build'; RequiresRequest = $true }
    'ppl-build'    = @{ Workflow = 'ppl-build'; RequiresRequest = $true }
}

if (-not $operationMap.ContainsKey($Operation)) {
    throw "Operation '$Operation' is not supported."
}

$entry = $operationMap[$Operation]
if ($entry.RequiresRequest -and [string]::IsNullOrWhiteSpace($RequestPath)) {
    throw "Operation '$Operation' requires -RequestPath."
}

$invokeArgs = @('-Workflow', $entry.Workflow)
if ($RequestPath) {
    $invokeArgs += @('-RequestPath', $RequestPath)
}
if ($Arguments) {
    $invokeArgs += @('-AdditionalArgs', $Arguments)
}
if ($RepoRoot) {
    $invokeArgs += @('-RepoRoot', $RepoRoot)
}

& $helperPath @invokeArgs
