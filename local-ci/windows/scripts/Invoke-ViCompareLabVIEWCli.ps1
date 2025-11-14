#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RepoRoot,
    [Parameter(Mandatory)][string]$RequestsPath,
    [Parameter(Mandatory)][string]$OutputRoot,
    [string[]]$ProbeRoots,
    [string]$LabVIEWExePath = 'C:\Program Files\National Instruments\LabVIEW 2025\LabVIEW.exe',
    [string]$HarnessScript,
    [int]$MaxPairs = 25,
    [int]$TimeoutSeconds = 900,
    [string]$NoiseProfile = 'full',
    [switch]$DisableCli,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:LOCALCI_DEBUG_VICOMPARE -eq '1') {
    $boundSummary = ($PSBoundParameters.GetEnumerator() | ForEach-Object { '{0}={1}' -f $_.Key, $_.Value })
    Write-Host ("[vicompare-cli] Args: {0}" -f ($boundSummary -join ', '))
    if ($args -and $args.Count -gt 0) {
        Write-Host ("[vicompare-cli] Extra args: {0}" -f ($args -join ' '))
    }
}

function Resolve-ExistingPath {
    param(
        [string]$PathValue,
        [string[]]$Roots
    )
    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return $null
    }
    $normalized = $PathValue.Trim()
    if ([System.IO.Path]::IsPathRooted($normalized)) {
        if (Test-Path -LiteralPath $normalized -PathType Leaf) {
            return (Resolve-Path -LiteralPath $normalized).ProviderPath
        }
        return $null
    }

    foreach ($root in ($Roots | Where-Object { $_ })) {
        $candidate = Join-Path $root $normalized
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).ProviderPath
        }
    }
    return $null
}

function Get-PropertyValue {
    param(
        $Object,
        [string]$Name
    )
    if ($null -eq $Object -or [string]::IsNullOrEmpty($Name)) { return $null }
    $prop = $Object.PSObject.Properties[$Name]
    if ($prop) { return $prop.Value }
    return $null
}

function Read-ViDiffPairs {
    param([string]$RequestsPath)
    $raw = Get-Content -LiteralPath $RequestsPath -Raw
    $data = $raw | ConvertFrom-Json -Depth 8
    if (-not $data) {
        throw "Unable to parse VI diff requests from $RequestsPath"
    }

    $pairs = New-Object System.Collections.Generic.List[object]

    $requestsNode = Get-PropertyValue -Object $data -Name 'requests'
    if ($requestsNode) {
        foreach ($req in $requestsNode) {
            $pairId = Get-PropertyValue -Object $req -Name 'pairId'
            if (-not $pairId) { $pairId = Get-PropertyValue -Object $req -Name 'relPath' }
            if (-not $pairId) { $pairId = Get-PropertyValue -Object $req -Name 'name' }
            $label = Get-PropertyValue -Object $req -Name 'name'
            if (-not $label) { $label = Get-PropertyValue -Object $req -Name 'relPath' }
            if (-not $label) { $label = $pairId }
            $category = Get-PropertyValue -Object $req -Name 'category'
            if (-not $category) { $category = 'vi-compare' }

            $baseline = $null
            $candidate = $null
            if ($req.PSObject.Properties['base']) { $baseline = $req.base }
            if ($req.PSObject.Properties['head']) { $candidate = $req.head }
            $baselineObj = Get-PropertyValue -Object $req -Name 'baseline'
            $candidateObj = Get-PropertyValue -Object $req -Name 'candidate'
            if (-not $baseline -and $baselineObj) { $baseline = Get-PropertyValue -Object $baselineObj -Name 'path' }
            if (-not $candidate -and $candidateObj) { $candidate = Get-PropertyValue -Object $candidateObj -Name 'path' }

            $pairs.Add([pscustomobject]@{
                Id        = $pairId
                Label     = $label
                Category  = $category
                RelPath   = Get-PropertyValue -Object $req -Name 'relPath'
                Baseline  = $baseline
                Candidate = $candidate
            })
        }
        return ,$pairs
    }

    $pairsNode = Get-PropertyValue -Object $data -Name 'pairs'
    if ($pairsNode) {
        foreach ($pair in $pairsNode) {
            $pairId = Get-PropertyValue -Object $pair -Name 'pair_id'
            $labels = Get-PropertyValue -Object $pair -Name 'labels'
            $labelText = $null
            if ($labels) {
                $labelText = ($labels | Where-Object { $_ }) -join ', '
            }
            if (-not $labelText) { $labelText = $pairId }
            $pairs.Add([pscustomobject]@{
                Id        = $pairId
                Label     = $labelText
                Category  = 'vi-compare'
                RelPath   = $pairId
                Baseline  = (Get-PropertyValue -Object (Get-PropertyValue -Object $pair -Name 'baseline') -Name 'path')
                Candidate = (Get-PropertyValue -Object (Get-PropertyValue -Object $pair -Name 'candidate') -Name 'path')
            })
        }
        return ,$pairs
    }

    throw "Unrecognized vi-diff request schema in $RequestsPath"
}

function Write-StubArtifacts {
    param(
        [string]$PairRoot,
        [string]$Reason,
        [string]$Status = 'dry-run'
    )
    $capture = [ordered]@{
        schema  = 'labview-cli-capture@v1'
        status  = $Status
        reason  = $Reason
        at      = (Get-Date).ToString('o')
    }
    $capture | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $PairRoot 'lvcompare-capture.json') -Encoding UTF8

    $session = [ordered]@{
        schema  = 'teststand-compare-session/v1'
        at      = (Get-Date).ToString('o')
        status  = $Status
        reason  = $Reason
    }
    $session | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $PairRoot 'session-index.json') -Encoding UTF8

    $encoded = [System.Net.WebUtility]::HtmlEncode($Reason)
    $html = @"
<!DOCTYPE html>
<html><head><meta charset='utf-8'><title>VI Compare ($Status)</title></head>
<body><p>$encoded</p></body></html>
"@
    $html | Set-Content -LiteralPath (Join-Path $PairRoot 'compare-report.html') -Encoding UTF8
}

if (-not (Test-Path -LiteralPath $RequestsPath -PathType Leaf)) {
    throw "Requests file not found: $RequestsPath"
}

if (-not (Test-Path -LiteralPath $OutputRoot -PathType Container)) {
    New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
}

$ProbeRoots = $ProbeRoots | Where-Object { $_ }
if (-not $ProbeRoots) {
    $ProbeRoots = @($RepoRoot)
}

if (-not $HarnessScript) {
    $HarnessScript = Join-Path $RepoRoot 'src/tools/TestStand-CompareHarness.ps1'
}

$pairs = Read-ViDiffPairs -RequestsPath $RequestsPath
if (-not $pairs -or $pairs.Count -eq 0) {
    Write-Warning "[vi-compare] No entries found in $RequestsPath"
    return
}

$capturesRoot = Join-Path $OutputRoot 'captures'
if (Test-Path -LiteralPath $capturesRoot) {
    Remove-Item -LiteralPath $capturesRoot -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Path $capturesRoot -Force | Out-Null

$forceDryRun = $DryRun.IsPresent -or $DisableCli.IsPresent
if (-not $forceDryRun) {
    if (-not $LabVIEWExePath -or -not (Test-Path -LiteralPath $LabVIEWExePath -PathType Leaf)) {
        Write-Warning "[vi-compare] LabVIEW executable not found at '$LabVIEWExePath'. Falling back to dry-run mode."
        $forceDryRun = $true
    }
    if (-not (Test-Path -LiteralPath $HarnessScript -PathType Leaf)) {
        Write-Warning "[vi-compare] Harness script '$HarnessScript' not found. Falling back to dry-run mode."
        $forceDryRun = $true
    }
}

$pwshPath = (Get-Command pwsh -ErrorAction SilentlyContinue | Select-Object -First 1)?.Source
if (-not $pwshPath) { $pwshPath = 'pwsh' }

$counts = [ordered]@{
    total     = [int]$pairs.Count
    compared  = 0
    same      = 0
    different = 0
    skipped   = 0
    dryRun    = 0
    errors    = 0
}

$results = New-Object System.Collections.Generic.List[object]
$index = 0

foreach ($pair in $pairs | Select-Object -First $MaxPairs) {
    $index++
    $pairLabel = if ($pair.Id) { $pair.Id } else { '{0:D4}' -f $index }
    $pairFolder = 'pair-{0:D3}' -f $index
    $pairRoot = Join-Path $capturesRoot $pairFolder
    New-Item -ItemType Directory -Path $pairRoot -Force | Out-Null

    $baselinePath = Resolve-ExistingPath -PathValue $pair.Baseline -Roots $ProbeRoots
    $candidatePath = Resolve-ExistingPath -PathValue $pair.Candidate -Roots $ProbeRoots
    $status = 'dry-run'
    $message = 'LabVIEW CLI disabled'

    if (-not $forceDryRun) {
        if (-not $baselinePath -or -not $candidatePath) {
            $status = 'skipped'
            $message = 'Unable to resolve baseline/head paths from request.'
            $counts.skipped++
            Write-StubArtifacts -PairRoot $pairRoot -Reason $message -Status $status
        } else {
            $cliArgs = @(
                '-NoLogo','-NoProfile','-File', $HarnessScript,
                '-BaseVi', $baselinePath,
                '-HeadVi', $candidatePath,
                '-LabVIEWPath', $LabVIEWExePath,
                '-OutputRoot', $pairRoot,
                '-NoiseProfile', $NoiseProfile,
                '-RenderReport',
                '-CloseLabVIEW',
                '-CloseLVCompare'
            )
            if ($TimeoutSeconds -gt 0) {
                $cliArgs += @('-TimeoutSeconds', $TimeoutSeconds)
            }

            Write-Host ("[vi-compare] Running LabVIEW CLI for pair {0} ({1} vs {2})" -f $pairLabel, $baselinePath, $candidatePath)
            $startParams = @{
                FilePath     = $pwshPath
                ArgumentList = $cliArgs
                Wait         = $true
                PassThru     = $true
            }
            if ($IsWindows) {
                $startParams['WindowStyle'] = 'Hidden'
            }
            $process = Start-Process @startParams
            $counts.compared++
            switch ($process.ExitCode) {
                0 {
                    $status = 'same'
                    $counts.same++
                    $message = 'LVCompare reported no differences.'
                }
                1 {
                    $status = 'different'
                    $counts.different++
                    $message = 'LVCompare reported differences.'
                }
                default {
                    $status = 'error'
                    $counts.errors++
                    $message = "LabVIEW CLI exited with code $($process.ExitCode)."
                    Write-StubArtifacts -PairRoot $pairRoot -Reason $message -Status $status
                }
            }
        }
    } else {
        $counts.dryRun++
        $status = 'dry-run'
        $message = 'Dry-run mode: LabVIEW CLI execution skipped.'
        Write-StubArtifacts -PairRoot $pairRoot -Reason $message -Status $status
    }

    $artifacts = @{}
    $capturePath = Join-Path $pairRoot 'lvcompare-capture.json'
    if (Test-Path -LiteralPath $capturePath -PathType Leaf) {
        $artifacts.captureJson = Join-Path 'captures' $pairFolder 'lvcompare-capture.json'
    }
    $sessionPath = Join-Path $pairRoot 'session-index.json'
    if (Test-Path -LiteralPath $sessionPath -PathType Leaf) {
        $artifacts.sessionIndex = Join-Path 'captures' $pairFolder 'session-index.json'
    }
    $reportPath = Join-Path $pairRoot 'compare-report.html'
    if (Test-Path -LiteralPath $reportPath -PathType Leaf) {
        $artifacts.reportHtml = Join-Path 'captures' $pairFolder 'compare-report.html'
    }

    $results.Add([pscustomobject]@{
        name      = $pair.Label ?? $pair.RelPath ?? $pairLabel
        relPath   = $pair.RelPath ?? $pairLabel
        category  = $pair.Category ?? 'vi-compare'
        pairId    = $pairLabel
        status    = $status
        message   = $message
        artifacts = $artifacts
    }) | Out-Null
}

$summary = [ordered]@{
    schema      = 'icon-editor/vi-diff-summary@v1'
    generatedAt = (Get-Date).ToString('o')
    counts      = $counts
    requests    = $results
}
$summaryPath = Join-Path $OutputRoot 'vi-comparison-summary.json'
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

Write-Host ("[vi-compare] LabVIEW CLI summary written to {0}" -f $summaryPath)
return $summary
