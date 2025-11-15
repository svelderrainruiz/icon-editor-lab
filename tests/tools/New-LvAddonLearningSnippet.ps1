#Requires -Version 7.0
[CmdletBinding()]
param(
    [int]$MaxRecords = 10,
    [string]$OutputPath,
    [string]$DevModeDir,
    [string]$InvocationPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = $env:WORKSPACE_ROOT
if (-not $root) {
    $root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..' '..') -ErrorAction Stop).ProviderPath
}

if ($DevModeDir) {
    $devmodeDir = (Resolve-Path -LiteralPath $DevModeDir -ErrorAction Stop).ProviderPath
    $xCliRoot = Split-Path -Parent (Split-Path -Parent $devmodeDir)
} else {
    $xCliRoot = Join-Path $root 'tools/x-cli-develop'
    $devmodeDir = Join-Path $xCliRoot 'temp_telemetry' 'labview-devmode'
}

if (-not (Test-Path -LiteralPath $devmodeDir -PathType Container)) {
    Write-Warning ("[lvaddon/learn] No labview-devmode telemetry directory found at '{0}'. Run LvAddon dev mode with x-cli simulation enabled first." -f $devmodeDir)
    return
}

if ($InvocationPath) {
    $invPath = (Resolve-Path -LiteralPath $InvocationPath -ErrorAction Stop).ProviderPath
} else {
    $invPath = Join-Path $devmodeDir 'invocations.jsonl'
}

if (-not (Test-Path -LiteralPath $invPath -PathType Leaf)) {
    Write-Warning ("[lvaddon/learn] No invocations.jsonl found at '{0}'. Ensure x-cli labview-devmode logging is enabled." -f $invPath)
    return
}

$lines = Get-Content -LiteralPath $invPath -ErrorAction Stop
if (-not $lines -or @($lines).Count -eq 0) {
    Write-Warning ("[lvaddon/learn] invocations.jsonl at '{0}' is empty." -f $invPath)
    return
}

if ($MaxRecords -le 0) { $MaxRecords = 10 }
$tail = $lines | Select-Object -Last $MaxRecords

$records = @()
foreach ($line in $tail) {
    if (-not $line) { continue }
    try {
        $records += (ConvertFrom-Json -InputObject $line -ErrorAction Stop)
    } catch {
        Write-Warning ("[lvaddon/learn] Failed to parse record: {0}" -f $_.Exception.Message)
    }
}

if (-not $records) {
    Write-Warning "[lvaddon/learn] No parseable labview-devmode records found in the selected tail."
    return
}

$sample = @()
foreach ($rec in $records) {
    $schema    = $null
    $lvVersion = $null
    $bitness   = $null
    $lvRoot    = $null
    $script    = $null
    $args      = $null
    $scenario  = $null
    $exitCode  = $null

    if ($rec -is [psobject]) {
        if ($rec.PSObject.Properties.Match('Schema').Count -gt 0) {
            $schema = $rec.Schema
        }
        if ($rec.PSObject.Properties.Match('LvVersion').Count -gt 0) {
            $lvVersion = $rec.LvVersion
        }
        if ($rec.PSObject.Properties.Match('Bitness').Count -gt 0) {
            $bitness = $rec.Bitness
        }
        if ($rec.PSObject.Properties.Match('LvaddonRoot').Count -gt 0) {
            $lvRoot = $rec.LvaddonRoot
        }
        if ($rec.PSObject.Properties.Match('Script').Count -gt 0) {
            $script = $rec.Script
        }
        if ($rec.PSObject.Properties.Match('Args').Count -gt 0) {
            $args = $rec.Args
        }
        if ($rec.PSObject.Properties.Match('Scenario').Count -gt 0) {
            $scenario = $rec.Scenario
        }
        if ($rec.PSObject.Properties.Match('ExitCode').Count -gt 0) {
            $exitCode = $rec.ExitCode
        }
    }

    $sample += [pscustomobject]@{
        Kind        = $rec.Kind
        Mode        = $rec.Mode
        Operation   = $rec.Operation
        Schema      = $schema
        LvVersion   = $lvVersion
        Bitness     = $bitness
        LvAddonRoot = $lvRoot
        Script      = $script
        Args        = $args
        Scenario    = $scenario
        ExitCode    = $exitCode
    }
}

$snippet = [pscustomobject]@{
    GeneratedAt       = (Get-Date).ToString('o')
    WorkspaceRoot     = $root
    XCliRoot          = $xCliRoot
    SourceLogPath     = $invPath
    SampleRecords     = $sample
    SchemaVersions    = ($sample | ForEach-Object {
        if ($_ -is [psobject] -and $_.PSObject.Properties.Match('Schema').Count -gt 0 -and $_.Schema) {
            $_.Schema
        } else {
            '<none>'
        }
    } | Sort-Object -Unique)
    Hint              = "Use this snippet to help refine LvAddon dev-mode x-cli simulation scenarios."
    AgentInstructions = @"
You are assisting with LvAddon dev-mode simulation for the labview-icon-editor stack.

- Look at SampleRecords[*].Operation, Mode, LvVersion, Bitness, LvAddonRoot, Script, and Args.
- Propose meaningful scenario names (e.g., 'timeout.add-token-2025-64', 'rogue.disable-compare').
- For each scenario, suggest:
  - The stderr text x-cli should emit (matching existing timeout/rogue patterns when applicable).
  - Exit code and whether it should be treated as success or failure.
- Keep suggestions compatible with existing PowerShell telemetry, which looks for:
  - 'Error:' lines and 'Timed out waiting for app to connect to g-cli' for timeouts.
  - 'Rogue LabVIEW' text for rogue-process detection.
"@
}

$providerSummaryPath = Join-Path $root 'tests/results/_agent/icon-editor/dev-mode-provider-summary.json'
if (Test-Path -LiteralPath $providerSummaryPath -PathType Leaf) {
    $snippet | Add-Member -NotePropertyName 'ProviderSummaryPath' -NotePropertyValue $providerSummaryPath -Force
}

$viHistoryRunSummaryPath = Join-Path $root 'tests/results/_agent/vi-history/vi-history-run-summary.json'
if (Test-Path -LiteralPath $viHistoryRunSummaryPath -PathType Leaf) {
    $snippet | Add-Member -NotePropertyName 'VIHistoryRunSummaryPath' -NotePropertyValue $viHistoryRunSummaryPath -Force
    $snippet.AgentInstructions += @"

Additionally, VI History run summaries are available:
- Open VIHistoryRunSummaryPath to see, per pr-vi-history run, how many targets matched vs diffed vs errored or were skipped.
- Use those aggregates to prioritize which operations or VIs need better scenario coverage or tooling fixes.
"@
}

$viHistoryFamilySummaryPath = Join-Path $root 'tests/results/_agent/vi-history/vi-history-family-summary.json'
if (Test-Path -LiteralPath $viHistoryFamilySummaryPath -PathType Leaf) {
    $snippet | Add-Member -NotePropertyName 'VIHistoryFamilySummaryPath' -NotePropertyValue $viHistoryFamilySummaryPath -Force
    $snippet.AgentInstructions += @"

VI History also has scenario families:
- Open VIHistoryFamilySummaryPath to see how many runs fall into vihistory.ok, vihistory.diff, vihistory.skipped, vihistory.error, or vihistory.empty.
- Use these family counts to decide where to focus new scenarios (for example, ensuring there is at least some coverage in each family, and investigating spikes in 'vihistory.error' or 'vihistory.diff').
"@
}

$vipmInstallSummaryPath = Join-Path $root 'tests/results/_agent/icon-editor/vipm-install-summary.json'
if (Test-Path -LiteralPath $vipmInstallSummaryPath -PathType Leaf) {
    $snippet | Add-Member -NotePropertyName 'VipmInstallSummaryPath' -NotePropertyValue $vipmInstallSummaryPath -Force
    $snippet.AgentInstructions += @"

VIPM install summaries are available:
- Open VipmInstallSummaryPath to understand, per provider/version/bitness, how often VIPM installs succeed vs fail.
- Use those aggregates to refine VIPM-related scenarios and to spot recurring dependency issues that might affect dev-mode and VI History stability.
"@
}

$handshakeSummaryPath = Join-Path $root 'tests/results/_agent/icon-editor/handshake-summary.json'
if (Test-Path -LiteralPath $handshakeSummaryPath -PathType Leaf) {
    $snippet | Add-Member -NotePropertyName 'HandshakeSummaryPath' -NotePropertyValue $handshakeSummaryPath -Force
    $snippet.AgentInstructions += @"

Handshake summaries are available:
- Open HandshakeSummaryPath to see how Ubuntu and Windows local-ci handshake runs align (Prep/VICompare statuses, imported coverage, pointer status).
- Use this to detect mismatches between Ubuntu runs and Windows consumers, and to prioritize scenarios that harden cross-runner parity.
"@
}

if (-not $OutputPath) {
    $OutputPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-learning-snippet.json'
}

$outDir = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}

$snippet | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding utf8
Write-Host ("[lvaddon/learn] Learning snippet written to {0}" -f $OutputPath) -ForegroundColor Cyan
