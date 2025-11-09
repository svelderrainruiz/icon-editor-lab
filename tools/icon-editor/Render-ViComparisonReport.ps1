#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SummaryPath,
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ArtifactValue {
    param(
        $Artifacts,
        [string]$PropertyName
    )

    if (-not $Artifacts) { return $null }
    if ($Artifacts -is [System.Collections.IDictionary]) {
        return $Artifacts[$PropertyName]
    }
    return $Artifacts.PSObject.Properties[$PropertyName]?.Value
}

if (-not (Test-Path -LiteralPath $SummaryPath -PathType Leaf)) {
    throw "SummaryPath '$SummaryPath' was not found."
}

$summary = Get-Content -LiteralPath $SummaryPath -Raw | ConvertFrom-Json -Depth 6
$counts = $summary.counts
$requests = @()
if ($summary.requests) {
    $requests = @($summary.requests)
}

$lines = @()
$lines += '## VI Comparison Report'
$lines += ''
if ($counts) {
    $lines += (
        "Compared: {0} total, {1} same, {2} different, {3} skipped, {4} dry-run, {5} errors." -f `
        ($counts.total ?? 0),
        ($counts.same ?? 0),
        ($counts.different ?? 0),
        ($counts.skipped ?? 0),
        ($counts.dryRun ?? 0),
        ($counts.errors ?? 0)
    )
} else {
    $lines += '- No aggregate counts were provided.'
}
$lines += ''
$lines += '| VI | Status | Message | Artifacts |'
$lines += '| --- | --- | --- | --- |'

if ($requests.Count -eq 0) {
    $lines += '| (none) | - | - | - |'
} else {
    foreach ($request in $requests) {
        $viLabel = if ($request.relPath) { $request.relPath } elseif ($request.name) { $request.name } else { '(unknown)' }
        $status = if ($request.status) { $request.status } else { 'unknown' }
        $message = if ($request.message) { $request.message } else { '' }

        $artifacts = @()
        $artifactNode = $null
        if ($request -and $request.PSObject.Properties['artifacts']) {
            $artifactNode = $request.artifacts
        }
        $capturePath = Get-ArtifactValue -Artifacts $artifactNode -PropertyName 'captureJson'
        if ($capturePath) { $artifacts += ("[capture]({0})" -f $capturePath) }
        $sessionPath = Get-ArtifactValue -Artifacts $artifactNode -PropertyName 'sessionIndex'
        if ($sessionPath) { $artifacts += ("[session-index]({0})" -f $sessionPath) }
        if ($artifacts.Count -eq 0) { $artifacts = @('—') }

        $lines += ('| {0} | {1} | {2} | {3} |' -f $viLabel, $status, $message, ($artifacts -join '<br/>'))
    }
}

$markdown = ($lines -join [Environment]::NewLine)

if ($OutputPath) {
    $dir = Split-Path -Parent $OutputPath
    if ($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    Set-Content -LiteralPath $OutputPath -Value $markdown -Encoding utf8
}

return $markdown
